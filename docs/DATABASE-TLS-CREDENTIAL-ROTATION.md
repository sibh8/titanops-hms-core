# Database TLS Encryption & Automated Credential Rotation
**Ticket Reference:** `TITANOPS-119`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Components:** `docker-compose.yml`, `terraform/modules/secrets/`, `k8s/external-secrets/`

---

## 1. Context & Motivation

Electronic health records require HIPAA-compliant transport encryption and zero-trust credential lifecycle management. Previously:
- JDBC connection URLs defaulted to `useSSL=false` and `allowPublicKeyRetrieval=true`.
- Database credentials used static plaintext defaults (`medicore_pass`, `root_pass`) across configurations.
- No automated rotation schedule existed to revoke and refresh credentials periodically.

`TITANOPS-119` remediates this by:
1. Enforcing strict TLS encryption and certificate verification (`useSSL=true&requireSSL=true&verifyServerCertificate=true`) on all database connection strings.
2. Sourcing credentials strictly from AWS Secrets Manager via External Secrets Operator.
3. Automating a 30-day credential rotation lifecycle via AWS Secrets Manager rotation resources.

---

## 2. JDBC Connection Hardening

JDBC parameters configured across `docker-compose.yml`, Kubernetes Secrets, and AWS Secrets Manager:
- `useSSL=true`: Enforces SSL/TLS negotiation on socket initialization.
- `requireSSL=true`: Rejects plaintext fallback if the database server does not support TLS.
- `verifyServerCertificate=true`: Validates the RDS MySQL server certificate against trusted CA certificates to prevent man-in-the-middle (MITM) attacks.

Formatted JDBC URL:
```
jdbc:mysql://<rds-endpoint>:3306/medicore_hms?useSSL=true&requireSSL=true&verifyServerCertificate=true
```

---

## 3. Automated Credential Rotation Architecture

Configured in `terraform/modules/secrets/main.tf`:
- **`aws_secretsmanager_secret_rotation.database`**:
  - Bound to `aws_secretsmanager_secret.database`.
  - Configured with `automatically_after_days = 30` to rotate credentials on a 30-day recurring cycle.
  - Linked to a dedicated rotation Lambda function with appropriate VPC subnet and security group access to RDS MySQL.
- **IAM Least Privilege**:
  - Role `db_rotation` with access restricted strictly to `secretsmanager:DescribeSecret`, `secretsmanager:GetSecretValue`, `secretsmanager:PutSecretValue`, and `secretsmanager:UpdateSecretVersionStage` on the specific database secret ARN.

```
       ┌───────────────────────────────┐
       │      AWS Secrets Manager      │
       │    (30-day Rotation Timer)    │
       └───────────────┬───────────────┘
                       │
                       │ Triggers Rotation Step
                       ▼
       ┌───────────────────────────────┐
       │     Rotation Lambda / IAM     │
       │ (createSecret, setSecret,     │
       │  testSecret, finishSecret)    │
       └───────────────┬───────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐      ┌─────────────────────────┐
│  AWS RDS MySQL   │      │ External Secrets Op.    │
│ (ALTER USER PASS)│      │ (syncs K8s datasource)  │
└──────────────────┘      └─────────────────────────┘
```

---

## 4. Verification

The automated verification suite in `scripts/test-db-tls-rotation.sh` verifies:
- TLS parameters in `docker-compose.yml` (`useSSL=true`, `verifyServerCertificate=true`).
- Absence of `useSSL=false` in environment database blocks.
- Secrets Manager payload enforcing TLS and server certificate verification.
- Automated secret rotation declaration and 30-day rotation rules in Terraform.
- IAM execution roles and least-privilege rotation policies.
- Elimination of hardcoded plaintext passwords in Helm templates.

Execution:
```bash
./scripts/test-db-tls-rotation.sh
```
All 10 automated verification checks pass.
