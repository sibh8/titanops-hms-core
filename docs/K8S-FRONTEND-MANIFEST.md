# Kubernetes Frontend Deployment, LoadBalancer & Ingress Manifest (TITANOPS-70)

## Overview & Background
The TitanOps HMS user interface is a modern Vite/React single-page application served via an Alpine-based Nginx webserver. Under **TITANOPS-70**, the declarative manifest `k8s/deployments/10-frontend.yaml` is delivered to provide high availability, zero-downtime health probing, non-root container isolation, and multi-tier external ingress routing via AWS Network Load Balancer (NLB) and Application Load Balancer (ALB).

---

## Architectural Implementation

### 1. High-Availability Deployment
- **Replica Configuration**: Configured with 2 replicas spanning worker nodes for zero-downtime rolling upgrades.
- **Health Probing**: Leverages the built-in Nginx `/health` endpoint for both Kubernetes `livenessProbe` and `readinessProbe`.
- **Security Hardening**:
  - Non-root user execution (`runAsUser: 101`, `runAsGroup: 101` matching Nginx).
  - Enforces `readOnlyRootFilesystem: true`.
  - Ephemeral writable storage (`emptyDir: {}`) mapped to `/tmp`, `/var/run` (for PID), and `/var/cache/nginx`.
  - Linux capability drop: `capabilities: { drop: ["ALL"] }`.

### 2. Service & Ingress Routing
- **LoadBalancer Service**: Direct external service with AWS NLB annotations (`service.beta.kubernetes.io/aws-load-balancer-type: "external"`) exposing port 80.
- **Application Load Balancer (ALB) Ingress**: Defines an AWS ALB Ingress resource (`alb.ingress.kubernetes.io/scheme: "internet-facing"`) with health check path `/health`, routing user traffic to the Nginx frontend pods.

---

## Automated Verification
Executed via `scripts/test-k8s-frontend-manifest.sh` (12/12 tests passing):
- YAML syntax and multi-document structure.
- Non-root UID 101 security and read-only filesystem validation.
- Healthcheck probe paths (`/health`).
- LoadBalancer service and AWS ALB ingress configuration.
