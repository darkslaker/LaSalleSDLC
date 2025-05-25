#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# bootstrap.sh – Instalador todo‑en‑uno para el laboratorio de CI/CD seguro
# -----------------------------------------------------------------------------
# Requisitos:
#   • Bash 4+, curl, git
#   • Permisos de sudo (Linux/macOS) para instalar paquetes.
#
# Funcionalidad:
#   1. Detecta SO (Ubuntu/Debian, Fedora/RHEL, macOS Intel/Apple Silicon)
#   2. Instala Docker, kubectl, Helm y Kind o Minikube según la plataforma
#   3. Clona el repositorio del laboratorio o actualiza si ya existe
#   4. Crea un clúster local (Kind o Minikube) usando el namespace "seguridad"
#   5. Ejecuta un make target inicial (opcional)
#
# Uso:
#   $ chmod +x bootstrap.sh && ./bootstrap.sh [--kind|--minikube] [--repo URL] [--skip-docker]
#
# Opciones:
#   --kind           Fuerza Kind incluso en arquitecturas compatibles con Minikube
#   --minikube       Fuerza Minikube (x86_64) e ignora detección automática
#   --repo URL       Repositorio Git a clonar (default: oficial de la clase)
#   --skip-docker    No intenta instalar Docker/Podman (ya instalado o en rootless)
#   --help           Muestra esta ayuda
#
set -euo pipefail
trap 'echo -e "\n[✖] Error en la línea $LINENO. Abortando."' ERR

DEFAULT_REPO="https://github.com/darkslaker/LaSalleSDLC.git"
REPO_URL="$DEFAULT_REPO"
USE_KIND="auto"          # auto|true|false
SKIP_DOCKER=false

# ---------------------------- Funciones utilitarias ---------------------------
command_exists() { command -v "$1" &>/dev/null; }
log()   { printf "\e[32m[✔] %s\e[0m\n" "$*"; }
warn()  { printf "\e[33m[!] %s\e[0m\n" "$*"; }
info()  { printf "[i] %s\n" "$*"; }

usage() {
  grep -E "^#   " "$0" | sed 's/^#   //'
  exit 1
}

# ---------------------------- Parseo de argumentos ---------------------------
while [[ ${1:-} ]]; do
  case "$1" in
    --kind)      USE_KIND="true" ;;
    --minikube)  USE_KIND="false";;
    --repo)      REPO_URL="$2"; shift ;;
    --skip-docker) SKIP_DOCKER=true ;;
    -h|--help)   usage ;;
    *) warn "Opción desconocida: $1"; usage ;;
  esac
  shift
done

OS=$(uname -s)
ARCH=$(uname -m)

# ---------------------- Instalación de dependencias base ----------------------
install_pkg_linux() {
  if command_exists apt-get; then sudo apt-get update -y && sudo apt-get install -y "$@"
  elif command_exists dnf; then sudo dnf install -y "$@"
  elif command_exists yum; then sudo yum install -y "$@"
  else
    warn "No se encontró un gestor de paquetes compatible (apt, yum, dnf). Instala manualmente: $*"; exit 1
  fi
}

install_docker() {
  if command_exists docker || command_exists podman; then
    info "Docker/Podman ya instalado."
    return
  fi
  if [[ "$OS" == "Darwin" ]]; then
    brew install --cask docker
    log "Docker Desktop instalado. Inicia la app para activar el daemon."
  else
    curl -fsSL https://get.docker.com | sudo bash
    sudo usermod -aG docker "$USER"
    log "Se instaló Docker Engine. Cierra sesión o ejecuta 'newgrp docker'."
  fi
}

install_kind() {
  if command_exists kind; then info "Kind ya instalado"; return; fi
  curl -Lo "$HOME/kind" https://kind.sigs.k8s.io/dl/v0.23.0/kind-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m)
  chmod +x "$HOME/kind" && sudo mv "$HOME/kind" /usr/local/bin/
  log "Kind instalado."
}

install_minikube() {
  if command_exists minikube; then info "Minikube ya instalado"; return; fi
  if [[ "$OS" == "Darwin" ]]; then
    brew install minikube
  else
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    chmod +x minikube && sudo mv minikube /usr/local/bin/
  fi
  log "Minikube instalado."
}

install_kubectl() {
  if command_exists kubectl; then info "kubectl ya instalado"; return; fi
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl"
  chmod +x kubectl && sudo mv kubectl /usr/local/bin/
  log "kubectl instalado."
}

install_helm() {
  if command_exists helm; then info "Helm ya instalado"; return; fi
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  log "Helm instalado."
}

# --------------------------- Lógica de instalación ----------------------------
log "Detectando plataforma: $OS $ARCH"

if [[ "$OS" == "Darwin" ]]; then
  if ! command_exists brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$($(brew --prefix)/bin/brew shellenv)"
  fi
fi

[[ "$SKIP_DOCKER" == true ]] || install_docker
install_kubectl
install_helm

# Decidir Kind/Minikube
if [[ "$USE_KIND" == "auto" ]]; then
  if [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
    USE_KIND="true"
  else
    USE_KIND="false"
  fi
fi

if [[ "$USE_KIND" == "true" ]]; then
  install_kind
else
  if [[ "$ARCH" != "x86_64" ]]; then warn "Minikube no soporta oficialmente $ARCH. Cambiando a Kind."; install_kind
  else install_minikube; fi
fi

# ---------------------------- Crear clúster local -----------------------------
create_cluster_kind() {
  if kind get clusters | grep -q seguridad-lab; then info "Cluster Kind seguridad-lab ya existe"; return; fi
  kind create cluster --name seguridad-lab --image kindest/node:v1.30.0 --wait 2m
}

create_cluster_minikube() {
  if minikube profile list | grep -q seguridad-lab; then info "Perfil Minikube seguridad-lab ya existe"; return; fi
  minikube start -p seguridad-lab --kubernetes-version=stable --driver=docker --memory=4096 --cpus=2
}

if [[ "$USE_KIND" == "true" ]]; then create_cluster_kind; else create_cluster_minikube; fi

# ------------------------------ Clonar repositorio ----------------------------
if [[ -d "$LAB_DIR" ]]; then
  info "Repositorio existente. Haciendo 'git pull'."
  git -C "$LAB_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$LAB_DIR"
fi

cd "$LAB_DIR"

# -------------------------- Post‑instalación opcional -------------------------
if command_exists make && grep -qE '^setup:' Makefile; then
  log "Ejecutando 'make setup'…"
  make setup
fi

log "¡Entorno listo! Utiliza 'kubectl get pods -A' para verificar que todo esté en marcha."
