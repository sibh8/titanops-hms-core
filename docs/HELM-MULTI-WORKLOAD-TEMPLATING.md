# Helm Multi-Workload Chart Templating (TITANOPS-72)

## Overview & Background
Prior to **TITANOPS-72**, deploying the TitanOps HMS suite with Helm required repeating `helm install` or `helm template` ten distinct times with individual microservice values files. Under this ticket, the foundational `helm/titanops-base` chart is extended to natively model and deploy all 10 workloads (9 Spring Boot microservices and 1 React/Vite frontend) in a single unified Helm release, while maintaining backwards compatibility with isolated single-service deployments.

---

## Architectural Implementation

### 1. Multi-Workload Dictionary (`values.yaml`)
`values.yaml` enumerates all 10 services under `services:`, mirroring the multi-container topology of `docker-compose.yml`:
- `patient-service` (port 8081)
- `appointment-service` (port 8082)
- `user-service` (port 8083)
- `billing-service` (port 8084)
- `encounter-service` (port 8085)
- `lab-service` (port 8086)
- `medication-service` (port 8087)
- `prescription-service` (port 8088)
- `provider-service` (port 8089)
- `frontend` (port 80 / LoadBalancer)

### 2. Dual-Mode Templating Engine
`templates/deployment.yaml`, `templates/service.yaml`, and `templates/pdb.yaml` dynamically evaluate release context:
- **Unified Cluster Deployment**: When deploying the entire application (e.g. `helm install titanops-hms helm/titanops-base`), the chart iterates through `services:` using Go templating `range`, synthesizing distinct Deployments, Services, and PodDisruptionBudgets.
- **Isolated Service Deployment**: When targeting a specific service (e.g. `helm upgrade --install patient-service ... -f helm/values/patient-service.yaml`), the chart scopes rendering strictly to the designated target release.

---

## Automated Verification
Executed via `scripts/test-helm-multi-workload.sh` (32/32 tests pass):
- Helm lint validation with zero errors.
- Verification of service dictionary enumeration in `values.yaml`.
- Full multi-workload template rendering verifying 10 Deployments and 10 Services.
- Dry-run installation verification.
