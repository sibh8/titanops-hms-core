# AWS Elastic Container Registry (ECR) Infrastructure (TITANOPS-68)

## Overview & Background
Previously, container images for TitanOps HMS were targeted for local Docker environments or manual uploads. Under **TITANOPS-68**, centralized container image repositories are defined as declarative Infrastructure-as-Code (IaC) via a dedicated Terraform module (`modules/ecr`), creating 10 independent ECR repositories (9 Java Spring Boot microservices and 1 React/Vite Nginx frontend).

---

## Architectural Implementation

### 1. Repository Definitions
The module provisions dedicated private repositories within the target AWS account and region:
- `medicore/patient-service` (port 8081)
- `medicore/appointment-service` (port 8082)
- `medicore/user-service` (port 8083)
- `medicore/billing-service` (port 8084)
- `medicore/encounter-service` (port 8085)
- `medicore/lab-service` (port 8086)
- `medicore/medication-service` (port 8087)
- `medicore/prescription-service` (port 8088)
- `medicore/provider-service` (port 8089)
- `medicore/frontend` (port 80 / Nginx)

### 2. Security & Compliance
- **Vulnerability Scanning**: Automated CVE vulnerability assessment on push enabled (`scan_on_push = true`).
- **Server-Side Encryption**: Repositories encrypted at rest using AWS KMS / AES-256.
- **Tag Immutability & Traceability**: Supports semver and commit SHA tags (`v*`, `sha-*`, `release-*`).

### 3. Automated Lifecycle & Cost Optimization
ECR lifecycle policies prevent unbounded storage costs:
- **Rule 1 (Untagged Images)**: Untagged intermediate build artifacts automatically expired after 14 days.
- **Rule 2 (Tagged Images)**: FIFO retention preserving the last 30 tagged releases per service, removing obsolete historical layers.

### 4. CI/CD Integration Outputs
The module outputs structured maps consumed by GitHub Actions and Helm deploy workflows:
- `ecr_repository_urls`: Repository URLs for Docker login, tag, and push.
- `ecr_repository_arns`: IAM ARNs enabling least-privilege IAM policies for GitHub Actions OIDC and EKS worker nodes.

---

## Automated Verification
Executed via `scripts/test-ecr-repositories.sh`:
- Canonical style check (`terraform fmt`) and schema validation (`terraform validate`).
- Completeness check across all 10 repositories.
- Lifecycle rule definitions and scan-on-push validation.
- Output mapping verification.
