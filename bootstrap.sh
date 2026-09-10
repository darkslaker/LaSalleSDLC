#!/usr/bin/env bash
set -euo pipefail

required=(docker kubectl minikube make git)
missing=()

for cmd in "${required[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Faltan herramientas requeridas: ${missing[*]}"
  echo "Consulta LABORATORIO.md para las instrucciones de instalación."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker está instalado, pero el daemon no está disponible."
  exit 1
fi

echo "Entorno base: OK"
echo "Siguiente paso: make pipeline"
