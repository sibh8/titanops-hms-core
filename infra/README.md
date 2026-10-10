# TitanOps HMS — Infrastructure as Code

Terraform infrastructure and application deployment for the TitanOps / MediCore HMS
platform. One modular stack deploys the full microservice suite either to **AWS (EKS +
RDS)** or to a local **minikube** cluster, driven entirely by a single YAML config file
per environment.

---

## Table of contents

- [Goals](#goals)
- [Directory layout](#directory-layout)
- [How it works](#how-it-works)
- [Configuration (`config.yaml`)](#configuration-configyaml)
- [App config (Helm values)](#app-config-helm-values)
- [Terraform modules](#terraform-modules)
- [CIS security controls](#cis-security-controls)
- [Enable / disable switches](#enable--disable-switches)
- [Prerequisites](#prerequisites)
- [Operational commands](#operational-commands)
- [Testing](#testing)
- [Remote state backend](#remote-state-backend)
- [Known limitations](#known-limitations)

---

## Goals

- **One stack, two targets.** The same Terraform and the same Helm charts deploy to AWS
  or to minikube. Developers can test the charts locally without any AWS access.
- **YAML-driven.** Operators edit a single `config.yaml` per environment. A thin
  Terraform `locals` wrapper (`yamldecode`) converts it into Terraform values — no
  hand-authored `.tfvars`.
- **Modular and reusable.** Every AWS concern and the per-service deployment is its own
  module. The root stack just wires them together.
- **Toggle anything.** Optional security/observability services and individual
  microservices are gated by config flags. Disabling one makes Terraform destroy it on
  the next apply.
- **Secure by default.** AWS modules apply CIS Benchmark (Level 1) controls out of the box.
- **Single environment focus** (`dev` for AWS, `local` for minikube), but the
  `environments/<env>` layout makes adding more trivial.

---

## Directory layout

```
infra/
├── README.md                      # this file
├── infra-stack/
│   ├── modules/                   # reusable Terraform modules
│   │   ├── vpc/                   # VPC, 3-tier subnets, NAT, IGW, flow logs
│   │   ├── eks/                   # EKS cluster + managed node group + OIDC/IRSA
│   │   ├── rds/                   # RDS MySQL 8.0 Multi-AZ
│   │   ├── ecr/                   # ECR repositories (one per service)
│   │   ├── iam-oidc/              # GitHub Actions OIDC federation role
│   │   ├── cloudwatch/            # (optional) app log group
│   │   ├── guardduty/             # (optional) GuardDuty detector
│   │   ├── security-hub/          # (optional) Security Hub + CIS standard
│   │   ├── secrets-manager/       # (optional) DB credentials secret
│   │   ├── external-secrets/      # (optional) External Secrets Operator (Helm)
│   │   ├── minikube/              # local cluster lifecycle (minikube CLI)
│   │   └── helm-service/          # reusable per-service Helm release
│   └── hms-core-stack/            # the Terraform root — run terraform here
│       ├── versions.tf            # TF/provider pins + (commented) S3 backend
│       ├── providers.tf           # aws / kubernetes / helm providers
│       ├── locals.tf              # YAML → Terraform wrapper
│       ├── main.tf                # module wiring (count-gated by target/features)
│       ├── apps.tf                # per-service deploy (for_each enabled services)
│       ├── variables.tf           # env name + sensitive db_password
│       └── outputs.tf
├── environments/
│   ├── dev/                       # target: aws
│   │   ├── infra-config/config.yaml
│   │   └── app-config/*.yaml      # 10 Helm-compatible service value files
│   └── local/                     # target: local (minikube)
│       ├── infra-config/config.yaml
│       └── app-config/*.yaml
├── scripts/
│   ├── hms.sh                     # wrapper: run the stack for an environment (bash)
│   └── hms.ps1                    # wrapper (PowerShell)
└── test/
    ├── validate.sh / validate.ps1 # offline static validation suite
    └── smoke-aws.sh / smoke-aws.ps1  # live AWS smoke + CIS benchmark checks
```

---

## How it works

The root stack (`hms-core-stack`) reads the environment selected by `-var env=<name>`:

```
environments/<env>/infra-config/config.yaml   →  yamldecode()  →  local.cfg
environments/<env>/app-config/<service>.yaml   →  Helm values for each service
```

`locals.tf` decodes the config into typed Terraform values: `target`, `features`,
`minikube`, `services`, and per-target Helm `overrides`. Every module is then gated:

- **AWS modules** (`vpc`, `eks`, `rds`, `ecr`, `iam-oidc`) run only when `target: aws`.
- **Optional modules** run only when both `target: aws` and their `features.<name>` flag
  is `true`.
- **The minikube module** runs only when `target: local` (and `minikube.autostart`).
- **Each microservice** is deployed via the `helm-service` module through a `for_each`
  over the *enabled* services.

The same `helm/titanops-base` chart (in the repository root `helm/` folder) is used for
both targets, so a chart that works on minikube works on EKS.

```
          config.yaml (YAML, single source of truth)
                 │  yamldecode
                 ▼
          locals.tf  ──►  target? aws / local
                 │
     ┌───────────┴───────────────┐
     ▼ (aws)                      ▼ (local)
 VPC·EKS·RDS·ECR·IAM        minikube module
 + optional features              │
     │                            │
     └──────────► helm-service (×N enabled services) ◄──┘
                   using helm/titanops-base + app-config/<svc>.yaml
```

---

## Configuration (`config.yaml`)

Everything an operator changes lives in `environments/<env>/infra-config/config.yaml`.

### AWS environment (`dev`)

```yaml
name: titanops-hms
target: aws
namespace: hms

tags: { Project: titanops-hms, Environment: dev, ManagedBy: terraform }

aws:
  region: ap-south-1
  vpc_cidr: 10.0.0.0/16
  azs: [ap-south-1a, ap-south-1b]
  public_subnets:      [10.0.1.0/24, 10.0.2.0/24]
  private_app_subnets: [10.0.11.0/24, 10.0.12.0/24]
  private_db_subnets:  [10.0.21.0/24, 10.0.22.0/24]
  k8s_version: "1.30"
  eks_public_access: false
  node_instance_type: m5.large
  node_desired: 2
  node_min: 2
  node_max: 4

database:
  name: medicore_hms
  username: medicore
  instance_class: db.t3.medium
  multi_az: true

github:
  org: sibh8
  repo: titanops-hms-core
  branches: [main]

features:                 # optional services — demo toggles (see below)
  cloudwatch: false
  guardduty: false
  security_hub: false
  secrets_manager: false
  external_secrets: false

services:                 # per-service enable switch
  patient-service: { enabled: true }
  # ... all 10
```

### Local environment (`local`)

```yaml
name: titanops-hms
target: local
namespace: hms

minikube:                 # Terraform spins this up via the minikube CLI
  profile: hms-core
  driver: docker
  cpus: 4
  memory: 8192
  kubernetes_version: stable
  autostart: true
  delete_on_destroy: true

database: { name: medicore_hms, username: medicore }

features: { ... all false ... }   # AWS features never apply locally
services: { ... same 10 ... }
```

> The DB password is **not** stored in YAML. It is injected at apply time via the
> `TF_VAR_db_password` environment variable (or `-var db_password=...`).

---

## App config (Helm values)

Each file in `environments/<env>/app-config/<service>.yaml` is a plain Helm values
override for the `titanops-base` chart — the exact same shape as `helm/values/*.yaml`.

- **`local`** files mirror the existing repo Helm values and point at the in-cluster
  `medicore-mysql` database.
- **`dev`** files add `replicaCount: 2` and omit `SPRING_DATASOURCE_URL`; the stack
  injects the live RDS endpoint through a Helm override.

The 10 services and their ports:

| Service | Port | | Service | Port |
|---|---|---|---|---|
| patient-service | 8081 | | lab-service | 8086 |
| appointment-service | 8082 | | medication-service | 8087 |
| user-service | 8083 | | prescription-service | 8088 |
| billing-service | 8084 | | provider-service | 8089 |
| encounter-service | 8085 | | frontend | 80 |

---

## Terraform modules

| Module | Purpose |
|---|---|
| `vpc` | VPC `10.0.0.0/16`, public + private-app + private-db subnets across 2 AZs, IGW, NAT per AZ, route tables, VPC flow logs. |
| `eks` | EKS control plane, managed node group (`m5.large`), OIDC provider for IRSA, IMDSv2 launch template, control-plane logging. |
| `rds` | RDS MySQL 8.0, Multi-AZ, encrypted, private, TLS-required parameter group, backups, deletion protection. |
| `ecr` | One ECR repo per service with scan-on-push, immutable tags, lifecycle policy. |
| `iam-oidc` | GitHub Actions OIDC federation role scoped to ECR push + EKS describe (no static keys). |
| `cloudwatch` *(opt)* | CloudWatch log group for application/container logs. |
| `guardduty` *(opt)* | GuardDuty detector. |
| `security-hub` *(opt)* | Security Hub account + CIS AWS Foundations standard subscription. |
| `secrets-manager` *(opt)* | KMS-encrypted secret holding DB credentials. |
| `external-secrets` *(opt)* | External Secrets Operator (Helm) to sync secrets into the cluster. |
| `minikube` | Starts/deletes a local minikube cluster via the CLI (local target only). |
| `helm-service` | Reusable per-service Helm release using `titanops-base` + an app-config file. |

---

## CIS security controls

The AWS modules apply **CIS Benchmark Level 1** controls by default:

- **VPC** — flow logs to CloudWatch (CIS 3.9); default security group has no rules
  (CIS 5.3); no security group opens SSH/22 to `0.0.0.0/0` (CIS 5.2).
- **EKS** — control-plane audit logging (CIS EKS 2.1.1); private API endpoint
  (CIS EKS 5.4.1); envelope encryption of secrets with KMS; worker nodes enforce IMDSv2.
- **RDS** — encryption at rest; not publicly accessible; Multi-AZ; automated backups;
  deletion protection; TLS required.
- **ECR** — image scan on push; immutable tags; KMS encryption.
- **IAM** — GitHub OIDC federation instead of long-lived access keys; least-privilege role.
- **Detective controls** *(optional)* — GuardDuty and Security Hub with the CIS AWS
  Foundations standard.

These are verified against a live deployment by the smoke test (see [Testing](#testing)).

---

## Enable / disable switches

Both optional AWS features and individual microservices are controlled from
`config.yaml`. The mechanism is Terraform `count` / `for_each` gating:

- Set `features.guardduty: true` → GuardDuty is created on the next `apply`.
- Set it back to `false` → Terraform **destroys** GuardDuty on the next `apply`.
- Set `services.lab-service.enabled: false` → the lab-service Helm release is removed.

This makes it safe to enable the heavier security services only for demos, then turn
them off to keep the environment lean.

---

## Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Terraform | >= 1.5 | everything |
| AWS CLI | v2 | AWS target + smoke tests |
| kubectl | recent | inspecting either cluster |
| Helm | 3.x | chart troubleshooting (Terraform drives Helm itself) |
| minikube + a driver (docker/hyperv) | recent | local target |
| jq | any | smoke test (bash) |
| PowerShell | 7+ | the `.ps1` scripts |

For the AWS target, configure credentials (`aws configure` / SSO / env vars) and export
the DB password:

```bash
export TF_VAR_db_password='your-strong-password'      # bash
$env:TF_VAR_db_password = 'your-strong-password'      # PowerShell
```

---

## Operational commands

The wrapper scripts resolve all paths for you and inject `-var env=<env>`. Run them from
anywhere in the repo.

### Using the wrapper scripts (recommended)

```bash
# bash — ./infra/scripts/hms.sh <env> <action> [extra terraform args]
infra/scripts/hms.sh local apply            # spin up minikube + deploy all services
infra/scripts/hms.sh local destroy          # tear down local cluster + releases
infra/scripts/hms.sh dev plan               # preview AWS changes
infra/scripts/hms.sh dev apply -auto-approve
infra/scripts/hms.sh dev output             # show stack outputs
```

```powershell
# PowerShell — infra\scripts\hms.ps1 -Environment <env> -Action <action>
infra\scripts\hms.ps1 local apply
infra\scripts\hms.ps1 dev plan
infra\scripts\hms.ps1 -Environment dev -Action apply -Extra '-auto-approve'
```

Supported actions: `init | plan | apply | destroy | fmt | validate | output | console`.
The wrapper auto-runs `init` if the working directory isn't initialized yet.

### Raw Terraform (equivalent)

```bash
cd infra/infra-stack/hms-core-stack
terraform init
terraform plan   -var env=dev
terraform apply  -var env=dev
terraform destroy -var env=local
```

### Common recipes

```bash
# Local developer loop
export TF_VAR_db_password=localpass
infra/scripts/hms.sh local apply
kubectl --context hms-core -n hms get pods
infra/scripts/hms.sh local destroy

# Enable a security feature for a demo (edit config.yaml first)
#   features: { guardduty: true, security_hub: true }
infra/scripts/hms.sh dev apply
# ...later, set them back to false and re-apply to remove them
infra/scripts/hms.sh dev apply

# Disable a single service (edit config.yaml: services.lab-service.enabled: false)
infra/scripts/hms.sh dev apply     # Terraform destroys just that release
```

---

## Testing

### Offline static validation — `test/validate.{sh,ps1}`

No AWS or cluster required. Runs `fmt -check`, `init -backend=false`, `validate`, and
config-logic assertions (via `terraform console`) for every environment: YAML decodes,
all 10 services enabled, disable-toggle removes a service, target modes are mutually
exclusive, and every enabled service has a matching app-config file.

```bash
infra/test/validate.sh
```
```powershell
infra\test\validate.ps1
```

Exit code `0` = all passed, `1` = failures. Current status: **15/15 passing**.

### Live AWS smoke + CIS checks — `test/smoke-aws.{sh,ps1}`

Requires an **applied AWS environment** and AWS CLI read access. Reads resource IDs from
Terraform outputs and probes the real account to confirm resources are healthy and the
CIS controls listed above are in force. Optional-feature checks report `SKIP` when the
feature is disabled.

```bash
infra/test/smoke-aws.sh dev
```
```powershell
infra\test\smoke-aws.ps1 -Environment dev
```

---

## Remote state backend

By default Terraform uses local state. For shared/team use, enable the encrypted,
versioned, locked S3 backend in `hms-core-stack/versions.tf` (currently commented):

```hcl
backend "s3" {
  bucket         = "titanops-hms-tfstate"
  key            = "hms-core/terraform.tfstate"
  region         = "ap-south-1"
  dynamodb_table = "titanops-hms-tflock"
  encrypt        = true
}
```

Create the bucket (versioning + encryption + block-public-access) and the DynamoDB lock
table first, then re-run `terraform init`.

---

## Known limitations

- **Validation scope.** The structure, provider resolution, YAML wrapper logic, and
  disable-toggle behavior are verified offline. A live `apply` against real AWS or a
  running minikube has **not** been executed in this repo, so runtime concerns (EKS auth,
  the minikube `local-exec`, the smoke test's live CLI queries) should be shaken out on a
  first real run.
- **Minikube creation** shells out to the `minikube` CLI via `null_resource` /
  `local-exec` because no native Terraform provider exists. It requires `minikube` plus a
  driver installed on the machine.
- **Single environment** per target for now (`dev`, `local`). Add more by creating a new
  folder under `environments/`.
- **Secrets.** For simplicity the app-config keeps DB credentials inline to match the
  existing Helm values. For AWS-grade secret handling, enable `secrets_manager` +
  `external_secrets`.
```
