# Kubernetes DataSource Secrets for AWS RDS Integration (TITANOPS-71)

## Overview & Background
Prior to **TITANOPS-71**, database credentials (`SPRING_DATASOURCE_PASSWORD`) were stored directly in plaintext within Helm values files (`helm/values/<service>.yaml`). Under this ticket, all plaintext database credentials have been completely eradicated from the repository. All 9 Spring Boot microservices now inject database credentials dynamically from a Kubernetes Secret named `titanops-datasource-credentials` pointing to AWS RDS MySQL.

---

## Architectural Implementation

### 1. Secret Architecture & Ingestion
The Kubernetes Secret `titanops-datasource-credentials` injects the following three environment variables into microservice pods:
- `SPRING_DATASOURCE_URL`: The JDBC connection string pointing to the AWS RDS MySQL cluster (e.g., `jdbc:mysql://<rds-endpoint>:3306/medicore_hms?useSSL=true&requireSSL=true`).
- `SPRING_DATASOURCE_USERNAME`: The database user (`medicore`).
- `SPRING_DATASOURCE_PASSWORD`: The encrypted database password securely retrieved from AWS Secrets Manager or CI/CD secret vaults.

### 2. Helm Manifest Integration
All 9 service value files configure `envFrom` to reference the secret:
```yaml
envFrom:
  - secretRef:
      name: titanops-datasource-credentials
```

When Helm renders `titanops-base/templates/deployment.yaml`, Kubernetes mounts the Secret keys directly into container environment variables at pod startup.

### 3. Declarative Template & CLI Generator
- **Template (`k8s/secrets/datasource-secret-template.yaml`)**: An environment-agnostic template describing the required secret structure.
- **Generator Script (`scripts/generate-datasource-secret.sh`)**: Dynamically constructs the Secret YAML using `kubectl create secret generic --dry-run=client -o yaml`, enabling secure deployment without ever committing secrets to version control.

---

## Automated Verification
Validated via `scripts/test-k8s-datasource-secrets.sh`:
- Zero occurrences of plaintext `SPRING_DATASOURCE_PASSWORD` across all Helm values.
- Verified that all 9 service values reference `titanops-datasource-credentials`.
- Validated secret generator script output and syntax.
- Rendered Helm deployment templates across all 9 microservices, confirming clean injection of `envFrom`.
