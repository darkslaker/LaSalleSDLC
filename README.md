# Laboratorio CI/CD 

Este repositorio contiene una aplicación vulnerable de Node.js junto con un pipeline de seguridad con Argo Workflows. El objetivo es demostrar cómo integrar herramientas como Semgrep y Trivy dentro de un flujo de trabajo automatizado en Kubernetes.

## Contenido

- `/app`: Código fuente vulnerable.
- `workflow.yaml`: Pipeline que ejecuta Semgrep y Trivy.
