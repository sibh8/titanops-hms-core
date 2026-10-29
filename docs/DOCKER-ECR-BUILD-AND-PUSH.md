# Multi-Service Docker Build and Amazon ECR Push Pipeline (TITANOPS-65)

## Overview & Background
Under **TITANOPS-65** (and child tickets `TITANOPS-76` through `TITANOPS-85`), the repository implements automated containerization pipelines for all 9 Spring Boot microservices and the Vite/React frontend. Each service is built, tagged with both semantic git commit SHAs and `latest`, and pushed to its dedicated AWS ECR repository (`medicore/<service-name>`).

---

## Architectural Implementation

### 1. Unified Build & Push Automation (`scripts/build-and-push-ecr.sh`)
- **CLI Flags**:
  - `--dry-run`: Validates command generation, tag naming, and Docker commands without requiring live network/AWS credentials.
  - `--build-java`: Executes Maven package builds across all 9 microservices.
- **Traceable Tagging Strategy**:
  - `${ECR_REGISTRY}/medicore/<service>:<short-git-sha>` for immutable auditability.
  - `${ECR_REGISTRY}/medicore/<service>:latest` for default deployment references.
- **Docker Buildx Integration**: Utilizes multi-stage caching and layer reuse.

### 2. Matrix GitHub Actions Workflow (`.github/workflows/build-and-push-all-ecr.yml`)
- **Parallelized Matrix Execution**: Concurrently builds and tags all 10 services.
- **OIDC AWS Authentication**: Connects to AWS ECR via short-lived GitHub Actions OIDC STS tokens without static IAM access keys.
- **Frontend Health Verification**: Tests built Nginx container image on port 80 and verifies health check response on `/health`.

---

## Service Mapping & Port Reference
| Service Name | Port | ECR Repository Target | Base Image | Security UID |
|---|---|---|---|---|
| `patient-service` | 8081 | `medicore/patient-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `appointment-service` | 8082 | `medicore/appointment-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `user-service` | 8083 | `medicore/user-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `billing-service` | 8084 | `medicore/billing-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `encounter-service` | 8085 | `medicore/encounter-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `lab-service` | 8086 | `medicore/lab-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `medication-service` | 8087 | `medicore/medication-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `prescription-service` | 8088 | `medicore/prescription-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `provider-service` | 8089 | `medicore/provider-service` | `eclipse-temurin:11-jre` | `10001:10001` |
| `frontend` | 80 | `medicore/frontend` | `nginx:1.25.5-alpine` | `101:101` |

---

## Automated Verification
Validated via `scripts/test-build-push-ecr.sh`:
- Dockerfile existence and non-root security context across all 10 services.
- Healthcheck endpoint verification on frontend image.
- Dry-run pipeline validation across all services.
- GitHub Actions workflow syntax validation.
