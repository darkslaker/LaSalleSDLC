# LaSalleSDLC — Laboratorio de CI/CD Seguro

Repositorio académico para practicar la integración de controles de seguridad dentro de un pipeline CI/CD.

## Objetivo

El laboratorio sigue este flujo:

```text
SAST → SCA/Secrets → SBOM → Build → Image Scan → Security Gate → Deploy → DAST
```

La meta no es ejecutar scanners de forma aislada, sino entender cómo sus resultados pueden convertirse en decisiones automáticas de despliegue.

## Estructura

```text
LaSalleSDLC/
├── app/                    # Aplicación Node.js deliberadamente vulnerable
├── .semgrep/               # Regla SAST controlada para el laboratorio
├── k8s/                    # Deployment y Job de Nuclei
├── nuclei/                 # Template DAST controlado
├── reports/                # SBOM generado durante el laboratorio
├── Makefile                # Pipeline local reproducible
└── LABORATORIO.md          # Instrucciones para el alumno
```

## Requisitos

- Docker
- kubectl
- Minikube
- Make
- Git

Las herramientas de seguridad se ejecutan desde contenedores; no es necesario instalar Semgrep, Trivy, Syft o Nuclei localmente.

## Inicio rápido

Después de clonar el repositorio, crea una rama de trabajo antes de modificar cualquier archivo:

```bash
git switch -c lab-secure-cicd
make preflight
make pipeline
```

La primera ejecución está diseñada para que el **Security Gate bloquee el despliegue** debido a una condición deliberadamente insegura en la imagen base. El error de `make` en ese punto es parte del ejercicio: identifica la causa, remédiala en tu rama, reconstruye y vuelve a validar.

Después del despliegue:

```bash
make dast
```

## ¿Qué hace Make?

`make` lee el archivo `Makefile` y ejecuta grupos de comandos definidos como **targets**. En este laboratorio lo usamos como una capa sencilla de automatización para representar las etapas de un pipeline antes de llevar la misma lógica a una plataforma CI/CD.

Por ejemplo, `make security-gate` ejecuta la receta asociada al target `security-gate`; si la política devuelve un código de error, Make detiene el pipeline y evita el deployment.

## Comandos principales

```bash
make help
make sast
make sca
make sbom
make build
make image-scan
make security-gate
make deploy
make dast
make pipeline
```

## Uso académico

La aplicación y los findings controlados se incluyen deliberadamente para fines educativos. No utilices esta aplicación como base para sistemas reales.
