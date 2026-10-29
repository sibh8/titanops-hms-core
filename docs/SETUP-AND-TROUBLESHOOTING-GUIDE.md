# TitanOps HMS: Master Setup & Troubleshooting Guide

## Overview
This master guide documents the installation, configuration, operational usage, and real-world troubleshooting steps for every layer of the **TitanOps Hospital Management System (HMS)** infrastructure under ticket **TITANOPS-45**.

It is written to enable any engineer to reproduce the complete production-grade cloud-native environment from scratch.

---

## 1. Stack Architecture & Prerequisites

### Tooling Requirements
- **AWS CLI**: v2.15+ (Configured with appropriate Administrator or CI credentials)
- **Terraform**: v1.5+
- **Ansible**: v2.14+
- **kubectl**: v1.28+
- **Helm**: v3.12+
- **Docker**: v24.0+
- **Node.js**: v18+ & **Java**: OpenJDK 11

---

## 2. GitHub Actions CI/CD Setup & Troubleshooting

### Setup & Usage
1. Configure AWS GitHub OIDC Identity Provider with thumbprint:
   - Audience: `sts.amazonaws.com`
   - Subject filter: `repo:sibh8/titanops-hms-core:*`
2. Pinned actions are enforced across all 26 workflows in `.github/workflows/` using 40-character commit SHAs.
3. Workflows execute build, packaging, security scans, Helm atomic rollout, post-deploy integration tests, and telemetry push.

### Real-World Troubleshooting
- **Issue 1: `AssumeRoleWithWebIdentity: OpenIDConnect provider not found or invalid audience`**
  - *Root Cause*: Mismatch between GitHub's token audience (`sts.amazonaws.com`) and IAM OIDC Provider configuration.
  - *Resolution*: Ensure `aws_iam_openid_connect_provider` specifies `sts.amazonaws.com` as the client ID and the repository subject string in the condition block matches `repo:sibh8/titanops-hms-core:ref:refs/heads/main`.
- **Issue 2: `GitHub Actions runner terminates with: No space left on device during Docker build`**
  - *Root Cause*: Building 9 Spring Boot microservice images concurrently exhausts runner disk.
  - *Resolution*: Utilize `reusable-ecr-push.yml` with BuildKit `--cache-from` and aggressive intermediate layer pruning via `docker system prune -af`.
- **Issue 3: `Cosign container image signature verification failure in downstream CD`**
  - *Root Cause*: Public key mismatch or OIDC subject claim divergence during keyless signing.
  - *Resolution*: Pass explicit certificate identity `--certificate-identity-regexp "https://github.com/sibh8/titanops-hms-core/.*"` to `cosign verify`.

---

## 3. Terraform Infrastructure Setup & Troubleshooting

### Setup & Usage
1. Navigate to `terraform/`:
   ```bash
   cd terraform
   terraform init -backend-config="bucket=titanops-tf-state-2026" -backend-config="key=prod/terraform.tfstate"
   terraform apply -var-file="environments/prod/terraform.tfvars"
   ```
2. Manages 9 core modules: `vpc`, `eks`, `rds`, `secrets`, `ecr`, `s3_backend`, `fluentbit`, `guardduty_securityhub`, `security_alerts`.

### Real-World Troubleshooting
- **Issue 1: `Module not installed: Run terraform init or terraform get`**
  - *Root Cause*: Adding new local module blocks without re-indexing the Terraform cache directory.
  - *Resolution*: Run `terraform get` or `terraform init -upgrade` whenever new modules (`modules/security_alerts`, `modules/guardduty_securityhub`) are authored.
- **Issue 2: `DBSubnetGroupDoesNotCoverEnoughAZs: RDS requires at least 2 Availability Zones`**
  - *Root Cause*: VPC subnet array assigned to DB Subnet Group had subnets located in the same AWS AZ.
  - *Resolution*: Enforce distinct availability zone mappings (`us-east-1a`, `us-east-1b`) in `modules/vpc/subnets.tf`.
- **Issue 3: `ConditionalCheckFailedException: DynamoDB lock acquisition timeout during CI concurrent apply`**
  - *Root Cause*: A dangling lock was retained after an ungracefully terminated CI job.
  - *Resolution*: Inspect lock info via `terraform force-unlock <LOCK-ID>` after verifying no concurrent operations are active.

---

## 4. Ansible Configuration Management Setup & Troubleshooting

### Setup & Usage
1. Located in `ansible/`:
   ```bash
   cd ansible
   ansible-galaxy install -r requirements.yml
   ansible-playbook -i inventory/aws_ec2.yml site.yml
   ```
2. Provisions host hardening, Docker daemon security configuration, log shippers, and CIS benchmark policies.

### Real-World Troubleshooting
- **Issue 1: `Host key verification failed during automated CI execution`**
  - *Root Cause*: Target EC2 instances rotated dynamic SSH host keys.
  - *Resolution*: Configure `ansible.cfg` with `host_key_checking = False` and strictly control bastion gateway access through security groups.
- **Issue 2: `Dynamic inventory aws_ec2 returns 0 hosts matching filter`**
  - *Root Cause*: Missing AWS environment credentials or missing tag filters on worker node launch templates.
  - *Resolution*: Verify `AWS_REGION` and ensure node tags match `tag:Project: TitanOps` and `instance-state-name: running`.
- **Issue 3: `Python interpreter discovery failed on minimal Linux worker AMI`**
  - *Root Cause*: Minimal worker OS lacks `/usr/bin/python`.
  - *Resolution*: Explicitly declare `ansible_python_interpreter: /usr/bin/python3` in `inventory/group_vars/all.yml`.

---

## 5. Helm & Kubernetes Deployment Setup & Troubleshooting

### Setup & Usage
1. Located in `helm/titanops-base/`:
   ```bash
   helm upgrade --install titanops-base helm/titanops-base \
     -f helm/environments/prod/values.yaml \
     --namespace hms --create-namespace --wait --atomic
   ```
2. Manages all 9 microservices, React UI, ExternalSecrets, NetworkPolicies, and Ingress routing.

### Real-World Troubleshooting
- **Issue 1: `Helm upgrade failed: timed out waiting for the condition (Atomic rollback triggered)`**
  - *Root Cause*: Pod liveness/readiness probes failing due to slow Spring Boot JVM initialization time.
  - *Resolution*: Adjust `initialDelaySeconds` to `60` and `periodSeconds` to `10` on microservice probes to accommodate JVM warmup.
- **Issue 2: `CustomResourceDefinition external-secrets.external-secrets.io not found`**
  - *Root Cause*: Installing application workload charts before installing the External Secrets Operator CRDs.
  - *Resolution*: Enforce chart dependency ordering or run `helm upgrade --install external-secrets` prior to applying application secrets manifests.
- **Issue 3: `0/3 nodes available: pod has unbound immediate PersistentVolumeClaims`**
  - *Root Cause*: StorageClass gp3 provisioner not installed or IAM EBS CSI Driver role missing.
  - *Resolution*: Install `aws-ebs-csi-driver` add-on with associated IRSA role `ebs-csi-controller-sa`.

---

## 6. Observability & Monitoring Setup & Troubleshooting

### Setup & Usage
1. Located in `k8s/monitoring/` and `k8s/observability/`:
   - OpenTelemetry Collector + Jaeger: Distributed tracing on ports 4317/16686.
   - Prometheus: Metric scraping on port 9090.
   - Grafana: Visualizations on port 3000.
   - Alertmanager: Alert dispatch on port 9093.

### Real-World Troubleshooting
- **Issue 1: `Prometheus target shows DOWN with connection refused on microservices`**
  - *Root Cause*: NetworkPolicy `default-deny-all` blocked ingress from the `monitoring` namespace to `hms`.
  - *Resolution*: Author `05-observability-network-policy.yaml` explicitly whitelisting TCP port `4317`, `8081-8089`, and `8889` from monitoring pods.
- **Issue 2: `Grafana dashboard provisioning overwrites imported dashboards`**
  - *Root Cause*: Conflicting provider folder names and allowUiUpdates settings.
  - *Resolution*: Configure dedicated providers with `options.path: /etc/grafana/dashboards` and unique provider names in `provider.yaml`.
- **Issue 3: `Alertmanager fails to dispatch alerts to Slack webhook`**
  - *Root Cause*: Missing outbound egress rule on port 443 in cluster NetworkPolicies.
  - *Resolution*: Ensure monitoring namespace egress rules permit outbound HTTPS traffic to AWS and public webhook APIs.

---

## 7. Verification

Verify the complete documentation suite:
```bash
./scripts/test-setup-troubleshooting-docs.sh
```
