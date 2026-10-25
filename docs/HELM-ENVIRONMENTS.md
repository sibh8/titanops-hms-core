# Helm Multi-Environment Parameterization Guide

**Ticket:** TITANOPS-50  
**Status:** In Progress / Implemented  
**Author:** Kaushal Patil (`patilkaushal89@gmail.com`)  
**Target:** Amazon EKS / Kubernetes (MediCore HMS)

---

## 1. Overview & Architecture

MediCore HMS uses a unified base Helm chart (`helm/titanops-base`) to deploy all 10 microservices (9 Spring Boot backend services and the React frontend).

To adhere to the twelve-factor application methodology and production-grade Kubernetes standards, environment-specific configurations (**Development**, **Staging**, and **Production**) are strictly decoupled from chart templates. 

### Configuration Layering Model

Configurations are evaluated in three distinct layers using Helm's multi-file values precedence:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Base Defaults (helm/titanops-base/values.yaml)           │
│    - Default probes, service types, labels, chart metadata  │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Overridden by)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Service Definitions (helm/values/<service>.yaml)         │
│    - Container port, image repository, service dependencies │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Overridden by)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Environment Overlays (helm/values-<env>.yaml)            │
│    - Replicas, HPA, Resources, Ingress, PDB, Logging, HA    │
└─────────────────────────────────────────────────────────────┘
```

Deploying any microservice to any environment is executed with standard Helm overlay chaining:
```bash
helm upgrade --install <service-name> helm/titanops-base \
  -f helm/values/<service-name>.yaml \
  -f helm/values-<environment>.yaml \
  --namespace hms-<environment> \
  --create-namespace \
  --set image.tag="<commit-sha-or-semver>"
```

---

## 2. Environment Comparison Matrix

| Configuration Attribute | Development (`dev`) | Staging (`staging`) | Production (`prod`) |
| :--- | :--- | :--- | :--- |
| **Target Audience** | Local & Feature Testing | Pre-production QA / UAT | Live Clinical Workloads |
| **Replica Count** | `1` (minimal cost) | `2` (redundancy validation) | `3` (high availability baseline) |
| **Autoscaling (HPA)** | Disabled | Disabled | **Enabled** (Min: 3, Max: 10, CPU: 70%, Mem: 80%) |
| **Pod Disruption Budget**| Disabled | `minAvailable: 1` | `minAvailable: 2` |
| **CPU (Req / Limit)** | `50m` / `250m` | `100m` / `500m` | `250m` / `1000m` |
| **Memory (Req / Limit)**| `128Mi` / `512Mi` | `256Mi` / `1024Mi` | `512Mi` / `2048Mi` |
| **Ingress Hostname** | `dev.medicore.titanops.io` | `staging.medicore.titanops.io` | `medicore.titanops.io` |
| **TLS / SSL Redirect** | Plain HTTP (Port 80) | TLS Enabled (HTTPS 443 + Redirect) | TLS Enabled (Strict HTTPS 443 + Redirect) |
| **WAF Protection** | None | None | **AWS WAFv2 WebACL Enforced** |
| **Spring Active Profile**| `dev` | `staging` | `prod` |
| **Log Level (Root)** | `DEBUG` | `INFO` | `WARN` |
| **Node Scheduling** | `environment: dev` | `environment: staging` + Soft Anti-Affinity | `m5.large` + Hard Anti-Affinity + AZ Zone Spread |
| **Multi-AZ Availability**| Single AZ acceptable | Best-effort multi-AZ | **Strict Zone Spread (`DoNotSchedule` skew 1)** |

---

## 3. Directory Structure

```
helm/
├── titanops-base/                    # Reusable base Helm chart
│   ├── Chart.yaml                    # Chart metadata (v0.1.0)
│   ├── values.yaml                   # Baseline defaults
│   └── templates/
│       ├── _helpers.tpl              # Dynamic template naming and environment labels
│       ├── deployment.yaml           # Deployment manifest (supports HPA, tolerations, spread)
│       ├── hpa.yaml                  # HorizontalPodAutoscaler (v2) template
│       ├── ingress.yaml              # Ingress (networking.k8s.io/v1) template with ALB/TLS
│       ├── pdb.yaml                  # PodDisruptionBudget (policy/v1) template
│       └── service.yaml              # ClusterIP service manifest
├── values/                           # Service-specific contracts
│   ├── appointment-service.yaml
│   ├── billing-service.yaml
│   ├── encounter-service.yaml
│   ├── frontend.yaml
│   ├── lab-service.yaml
│   ├── medication-service.yaml
│   ├── patient-service.yaml
│   ├── prescription-service.yaml
│   ├── provider-service.yaml
│   └── user-service.yaml
├── values-dev.yaml                   # Development environment overlay
├── values-staging.yaml               # Staging environment overlay
├── values-prod.yaml                  # Production environment overlay
├── environments/                     # Standard enterprise directory mapping
│   ├── dev/values.yaml
│   ├── staging/values.yaml
│   └── prod/values.yaml
└── verify-environments.sh            # Automated 55-check verification suite
```

---

## 4. Definition of Done Compliance Matrix

| Definition of Done Criterion | Status | Implementation Details |
| :--- | :---: | :--- |
| **1. Separate values files exist for at least dev and prod** | **Compliant** | `helm/values-dev.yaml`, `helm/values-staging.yaml`, and `helm/values-prod.yaml` exist and are mirrored under `helm/environments/`. |
| **2. Deploying with `-f values-dev.yaml` vs `-f values-prod.yaml` produces expected differences** | **Compliant** | Tested and verified via automated test suite `helm/verify-environments.sh` (55/55 tests passing). Confirms replicas (1 vs HPA 3-10), resources (50m/128Mi vs 250m/512Mi), ingress hosts, PDB, and zone spreads. |
| **3. No environment-specific values are hardcoded in templates** | **Compliant** | Verified via static AST/grep inspection. Zero instances of `dev`, `staging`, or `prod` appear in `helm/titanops-base/templates/`. All values are parameter-driven. |

---

## 5. Local Verification & Usage

Run the automated validation suite locally:
```bash
chmod +x helm/verify-environments.sh
./helm/verify-environments.sh
```

Generate rendered manifests for review:
```bash
# Render Patient Service for Development
helm template patient-service helm/titanops-base \
  -f helm/values/patient-service.yaml \
  -f helm/values-dev.yaml

# Render Patient Service for Production
helm template patient-service helm/titanops-base \
  -f helm/values/patient-service.yaml \
  -f helm/values-prod.yaml
```
