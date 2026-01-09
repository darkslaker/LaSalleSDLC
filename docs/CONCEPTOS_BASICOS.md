# Introducción a Cloud Native: De Docker a Kubernetes

Bienvenido al mundo del desarrollo moderno. Antes de sumergirnos en el laboratorio de seguridad, necesitamos entender las piezas fundamentales sobre las que se ejecuta nuestra infraestructura.

Vamos a usar una analogía: **Un puerto de carga marítimo internacional.**

## El Diagrama "Big Picture"

Este diagrama resume cómo se relacionan todos los componentes que vamos a ver. Mantenlo en mente mientras leemos las definiciones.

```mermaid
graph TD
    subgraph K8S ["Cluster de Kubernetes (El Puerto Marítimo)"]
        style K8S fill:#f0f8ff,stroke:#333,stroke-width:2px,color:#000

        ControlPlane["🧠 Control Plane / Master<br>(La Torre de Control)"]
        style ControlPlane fill:#e1f5fe,stroke:#0277bd,color:#000

        subgraph Node1 ["Worker Node 1 (Un Muelle de Carga)"]
            style Node1 fill:#fff3e0,stroke:#e65100,color:#000
            kubelet1["Kubelet<br>(El Capataz del Muelle)"]
            
            subgraph PodA ["Pod A (Un Vagón de Tren)"]
                style PodA fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#000
                Container1["🐳 Contenedor App<br>(Caja de Mudanza)"]
                style Container1 fill:#ffffff,stroke:#2e7d32,color:#000
            end
        end

         subgraph Node2 ["Worker Node 2 (Otro Muelle de Carga)"]
            style Node2 fill:#fff3e0,stroke:#e65100,color:#000
            kubelet2["Kubelet<br>(El Capataz del Muelle)"]

            subgraph PodB ["Pod B"]
                style PodB fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#000
                Container2["🐳 Contenedor BD"]
                style Container2 fill:#ffffff,stroke:#2e7d32,color:#000
                Container3["🐳 Contenedor Log Sidecar"]
                style Container3 fill:#f1f8e9,stroke:#2e7d32,stroke-dasharray: 5 5,color:#000
            end
        end
        
        ControlPlane -->|Da órdenes| kubelet1
        ControlPlane -->|Da órdenes| kubelet2
        kubelet1 -->|Gestiona| PodA
        kubelet2 -->|Gestiona| PodB
    end
