# Kubernetes Deployment & Service Manifests for All 9 Microservices (TITANOPS-69)

## Overview & Background
Under **TITANOPS-69** (and subtasks `TITANOPS-86` through `TITANOPS-94`), declarative, production-grade Kubernetes manifests have been authored in `k8s/deployments/` for all 9 Spring Boot microservices. Each microservice is provisioned with high-availability multi-replica deployments, least-privilege security contexts, actuator health probes, and isolated internal `ClusterIP` services.

---

## Service Mapping & Configuration Matrix
| Manifest File | Service Name | Service Port | Security UID/GID | Health Probes (Liveness/Readiness) |
|---|---|---|---|---|
| `01-patient-service.yaml` | `patient-service` | 8081 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `02-appointment-service.yaml` | `appointment-service` | 8082 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `03-user-service.yaml` | `user-service` | 8083 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `04-billing-service.yaml` | `billing-service` | 8084 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `05-encounter-service.yaml` | `encounter-service` | 8085 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `06-lab-service.yaml` | `lab-service` | 8086 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `07-medication-service.yaml` | `medication-service` | 8087 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `08-prescription-service.yaml` | `prescription-service` | 8088 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |
| `09-provider-service.yaml` | `provider-service` | 8089 | `10001:10001` | `/actuator/health/liveness`, `/actuator/health/readiness` |

---

## Architectural Hardening Features
1. **Dynamic Credential Injection**: Sourced via `envFrom: [ secretRef: { name: titanops-datasource-credentials } ]` guaranteeing zero plaintext secrets in manifests.
2. **Read-Only Root Filesystem & Ephemeral Storage**: Containers enforce `readOnlyRootFilesystem: true` with an emptyDir volume mounted at `/tmp` to support Tomcat PID/socket generation without file tampering risk.
3. **Capability Dropping**: Drops `ALL` Linux capabilities with `allowPrivilegeEscalation: false`.
4. **Predictable Scheduling**: Bounded resource limits (`cpu: 250m`, `memory: 256Mi`) and requests (`cpu: 100m`, `memory: 128Mi`).

---

## Verification & Automated Testing
Verified via `scripts/test-k8s-microservices-manifests.sh` (72/72 tests pass):
- Syntactic validation of all 9 YAML manifests.
- Compliance checks for non-root execution, secret references, probes, and resource constraints.
- In-cluster service port mappings.
