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

set -e # Detener el script si hay errores

# --- Variables Globales ---
REPO_URL="https://github.com/darkslaker/LaSalleSDLC.git"
USE_KIND=false
USE_MINIKUBE=false
SKIP_DOCKER=false
OS_TYPE=""
ARCH_TYPE=""
DISTRO=""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Funciones de Ayuda ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_help() {
    # Muestra el encabezado del archivo
    sed -n '2,17p' "$0"
}

# --- Parseo de Argumentos ---
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --kind)
        USE_KIND=true
        shift
        ;;
        --minikube)
        USE_MINIKUBE=true
        shift
        ;;
        --repo)
        REPO_URL="$2"
        shift 2
        ;;
        --skip-docker)
        SKIP_DOCKER=true
        shift
        ;;
        --help)
        print_help
        exit 0
        ;;
        *)
        log_error "Opción desconocida: $1"
        print_help
        exit 1
        ;;
    esac
done

# --- 1. Detección del Sistema ---
detect_os() {
    OS_TYPE=$(uname -s)
    ARCH_TYPE=$(uname -m)

    if [[ "$OS_TYPE" == "Linux" ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
        fi
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        DISTRO="macos"
    else
        log_error "Sistema operativo no soportado: $OS_TYPE"
        exit 1
    fi
    
    log_info "Sistema detectado: $OS_TYPE ($DISTRO) en arquitectura $ARCH_TYPE"
}

# --- 2. Instalación de Dependencias ---
install_dependencies() {
    log_info "Verificando dependencias..."

    # Docker
    if [[ "$SKIP_DOCKER" == "false" ]]; then
        if ! command -v docker &> /dev/null; then
            log_warn "Docker no encontrado. Intentando instalar..."
            if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
                sudo apt-get update && sudo apt-get install -y docker.io
                sudo usermod -aG docker $USER
                log_warn "Docker instalado. ES POSIBLE QUE NECESITES REINICIAR LA SESIÓN para usar docker sin sudo."
            elif [[ "$DISTRO" == "fedora" ]]; then
                sudo dnf install -y docker
                sudo systemctl start docker && sudo systemctl enable docker
                sudo usermod -aG docker $USER
            elif [[ "$DISTRO" == "macos" ]]; then
                if command -v brew &> /dev/null; then
                    brew install --cask docker
                else
                    log_error "Homebrew no encontrado. Instala Docker Desktop manualmente: https://www.docker.com/products/docker-desktop/"
                    exit 1
                fi
            fi
        else
            log_success "Docker ya está instalado."
        fi
    fi

    # Kubectl
    if ! command -v kubectl &> /dev/null; then
        log_info "Instalando Kubectl..."
        if [[ "$OS_TYPE" == "Linux" ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
        elif [[ "$OS_TYPE" == "Darwin" ]]; then
            brew install kubectl
        fi
    fi

    # Helm
    if ! command -v helm &> /dev/null; then
        log_info "Instalando Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
}

# --- 3. Gestión del Repositorio ---
setup_repo() {
    DIR_NAME=$(basename "$REPO_URL" .git)
    
    # Si ya estamos dentro del repo, no hacemos nada
    if [ -d ".git" ] && grep -q "LaSalleSDLC" .git/config; then
        log_info "Ya estás dentro del repositorio."
        git pull origin main
    elif [ -d "$DIR_NAME" ]; then
        log_info "Directorio $DIR_NAME encontrado. Actualizando..."
        cd "$DIR_NAME"
        git pull origin main
    else
        log_info "Clonando repositorio $REPO_URL..."
        git clone "$REPO_URL"
        cd "$DIR_NAME"
    fi
}

# --- 4. Creación del Clúster ---
setup_cluster() {
    # Verificar Docker Daemon
    if ! docker info > /dev/null 2>&1; then
        log_error "El daemon de Docker no está corriendo. Inícialo e intenta de nuevo."
        exit 1
    fi

    # Lógica de selección de Cluster Tool
    # Por defecto usamos Minikube, salvo en Apple Silicon (ARM64) donde Kind suele ser más estable/rápido,
    # a menos que el usuario fuerce lo contrario.
    
    TOOL="minikube"
    
    if [[ "$USE_KIND" == "true" ]]; then
        TOOL="kind"
    elif [[ "$USE_MINIKUBE" == "true" ]]; then
        TOOL="minikube"
    elif [[ "$ARCH_TYPE" == "arm64" && "$OS_TYPE" == "Darwin" ]]; then
        log_info "Apple Silicon detectado. Se sugiere usar Kind, pero intentaremos Minikube (driver docker) por compatibilidad."
        TOOL="minikube" 
    fi

    log_info "Preparando clúster usando: $TOOL"

    if [[ "$TOOL" == "minikube" ]]; then
        if ! command -v minikube &> /dev/null; then
            log_info "Instalando Minikube..."
            if [[ "$OS_TYPE" == "Linux" ]]; then
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                sudo install minikube-linux-amd64 /usr/local/bin/minikube
            elif [[ "$OS_TYPE" == "Darwin" ]]; then
                brew install minikube
            fi
        fi
        
        if minikube status | grep -q "Running"; then
            log_success "Minikube ya está corriendo."
        else
            minikube start --driver=docker --cpus=4 --memory=8192
        fi
    else
        # Instalación/Uso de KIND
        if ! command -v kind &> /dev/null; then
            log_info "Instalando Kind..."
            if [[ "$OS_TYPE" == "Darwin" ]]; then brew install kind; fi
            if [[ "$OS_TYPE" == "Linux" ]]; then 
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            fi
        fi
        
        if ! kind get clusters | grep -q "lasalle-lab"; then
            kind create cluster --name lasalle-lab
        else
            log_success "Clúster Kind 'lasalle-lab' ya existe."
        fi
    fi

    # Crear Namespace
    log_info "Configurando namespace 'seguridad'..."
    kubectl create namespace seguridad --dry-run=client -o yaml | kubectl apply -f -
}

# --- 5. Ejecución Final ---
run_makefile() {
    if [ -f "Makefile" ]; then
        log_info "Makefile detectado. Ejecutando configuración inicial..."
        # Asumiendo que existe un target 'setup' o 'install'. Si no, usa 'all' o nada.
        # Ajusta esto según lo que tengas en tu Makefile real.
        if grep -q "setup:" Makefile; then
            make setup
        else
            log_warn "No se encontró target 'setup' en Makefile. Saltando."
        fi
    else
        # Si no hay makefile, instalamos Argo manualmente como fallback
        log_info "No se encontró Makefile. Instalando Argo Workflows manualmente..."
        helm repo add argo https://argoproj.github.io/argo-helm
        helm repo update
        helm upgrade --install argo argo/argo-workflows -n argo --create-namespace --set server.serviceType=LoadBalancer
    fi
}

# --- Main ---
detect_os
install_dependencies
setup_repo
setup_cluster
run_makefile

log_success "==========================================="
log_success "   Laboratorio LaSalle desplegado con éxito"
log_success "==========================================="
log_info "Prueba ejecutar: kubectl get pods -n argo"