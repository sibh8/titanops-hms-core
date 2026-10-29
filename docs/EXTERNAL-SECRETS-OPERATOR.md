# AWS Secrets Manager Integration via External Secrets Operator (ESO)
**Ticket Reference:** `TITANOPS-127`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Module:** `terraform/modules/secrets/`, `k8s/external-secrets/`

---

## 1. Architectural Overview

The External Secrets Operator (ESO) bridges the gap between AWS Secrets Manager and Kubernetes native secrets. Rather than embedding database or monitoring credentials into git repositories, container images, or static manifests, ESO synchronizes secrets dynamically at runtime directly from AWS Secrets Manager using AWS IAM Roles for Service Accounts (IRSA).

```
   AWS Secrets Manager
   ┌────────────────────────────────────────┐
   │ titanops/prod/database-credentials     │
   │ titanops/prod/grafana-admin-credentials│
   └───────────────────┬────────────────────┘
                       │
                       │ OIDC / IRSA Authentication
                       ▼
       ┌───────────────────────────────┐
       │   External Secrets Operator   │
       │   (SecretStore & Controllers) │
       └───────────────┬───────────────┘
                       │
                       │ Automates K8s Secret Sync
                       ▼
       ┌───────────────────────────────┐
       │  Kubernetes Native Secrets    │
       │  - titanops-datasource-creds  │
       │  - grafana-admin-credentials  │
       └───────────────┬───────────────┘
                       │
                       │ Mounted via envFrom / secretKeyRef
                       ▼
       ┌───────────────────────────────┐
       │ 10 TitanOps HMS Microservices │
       │ & Observability Components    │
       └───────────────────────────────┘
```

---

## 2. Infrastructure as Code (Terraform)

Located in `terraform/modules/secrets/`:
1. **Secrets Provisioning:**
   - `aws_secretsmanager_secret.database`: Secret container with KMS customer master key encryption.
   - `aws_secretsmanager_secret_version.database`: Key-value JSON payload containing `username`, `password`, `host`, `port`, `dbname`, and JDBC connection strings.
   - `aws_secretsmanager_secret.grafana`: Grafana administrative admin user and password.
   - `random_password.db_password` & `random_password.grafana_password`: Cryptographically secure, uncommitted dynamic credentials.

2. **IAM Roles for Service Accounts (IRSA):**
   - Role `titanops-external-secrets-operator-role` with trust relationship to EKS OIDC provider.
   - Restricted policy granting `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`, and `kms:Decrypt` limited strictly to the `titanops/*` secret namespace.

---

## 3. Kubernetes ESO Manifests

Located in `k8s/external-secrets/`:
1. `01-eso-serviceaccount-secretstore.yaml`:
   - Configures `SecretStore` in namespace `titanops` connecting to AWS Secrets Manager (`eu-west-1`).
   - Authenticates using IRSA service account `external-secrets-sa`.
2. `02-database-external-secret.yaml`:
   - Maps `titanops/prod/database-credentials` into Kubernetes secret `titanops-datasource-credentials`.
   - Exports environment keys required by Spring Boot:
     - `SPRING_DATASOURCE_URL`
     - `SPRING_DATASOURCE_USERNAME`
     - `SPRING_DATASOURCE_PASSWORD`
   - Refresh interval: 1 hour (automatic drift resolution).
3. `03-grafana-external-secret.yaml`:
   - Synchronizes Grafana dashboard admin password to `grafana-admin-credentials` secret in namespace `monitoring`.

---

## 4. Verification and Validation

The test suite in `scripts/test-external-secrets-operator.sh` validates:
- Terraform module validation (`terraform validate`).
- AWS Secrets Manager secret definitions and KMS encryption.
- IRSA service account binding and IAM policy constraints.
- Kubernetes `SecretStore` and `ExternalSecret` manifest syntax and mapping targets.
- Elimination of plaintext credentials across Helm values and manifests.

Execution:
```bash
./scripts/test-external-secrets-operator.sh
```
All 10 test checks pass.
