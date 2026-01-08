# Laboratorio CI/CD 

Este repositorio contiene una aplicación vulnerable y un pipeline de seguridad automatizado que permite aplicar análisis estático y escaneo de vulnerabilidades dentro de un entorno Kubernetes local.

## 📦 Contenido

- `app/` - Aplicación Node.js vulnerable
- `pipeline.yaml` - Argo Workflow para ejecutar Semgrep y Trivy
- `chart/` - (Opcional) Helm chart si deseas extender el despliegue
- `README.md` - Guía del laboratorio
- `bootstrap.sh` - Script en bash version beta que instala los paquetes requeridos

## 🚀 Requisitos

- Docker Desktop
- Minikube
- WSL2 + Ubuntu (en Windows) o Linux/macOS
- kubectl
- helm
- Git

## 🔧 Instalación rápida

```bash
git clone git@github.com:darkslaker/LaSalleSDLC.git
cd LaSalleSDLC
minikube start --driver=docker --cpus=4 --memory=8192
kubectl create namespace argo
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo argo/argo-workflows -n argo
kubectl create namespace seguridad
kubectl apply -n seguridad -f pipeline.yaml
```

## 📊 Herramientas incluidas

- [Semgrep](https://semgrep.dev/) – Análisis estático de código
- [Trivy](https://aquasecurity.github.io/trivy/) – Escaneo de vulnerabilidades en archivos e imágenes

## 🧪 Actividades sugeridas

1. Explora el código vulnerable en `/app`
2. Ejecuta el pipeline y revisa los resultados
3. Agrega nuevas herramientas al flujo (ej. Nuclei)
4. Presenta tus hallazgos como parte del curso

## 📚 Recursos útiles

- https://owaspsamm.org/model/
- https://argoproj.github.io/argo-workflows/
- https://minikube.sigs.k8s.io/docs/

````markdown
```mermaid
graph TD
    User((👨‍💻 Estudiante)) -->|git push| Repo[GitHub Repo]
    Repo -->|Trigger| Argo[🐙 Argo Workflows]
    
    subgraph Pipeline de Seguridad
        direction TB
        Argo --> Clone[📥 Clone Code]
        Clone --> SAST[🔍 Semgrep (SAST)]
        Clone --> SCA[📦 Trivy (Dependencias)]
        
        SAST --> Decision{¿Vulnerables?}
        SCA --> Decision
    end
    
    Decision -->|No| Pass[✅ Aprobado]
    Decision -->|Sí| Fail[❌ Fallo / Reporte]
    
    classDef tools fill:#f9f,stroke:#333,stroke-width:2px;
    class Repo,Argo,SAST,SCA tools;

## 📬 ¿Preguntas?

Si eres alumno usa el canal oficial de la matareria para contactarme en otro caso abre un issue en este repo.

---
Repositorio académico para fines educativos en LaSalle.
