# Threat Detection with AWS GuardDuty EKS Protection & Security Hub
**Ticket Reference:** `TITANOPS-133`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Module:** `terraform/modules/guardduty_securityhub/`

---

## 1. Executive Summary

Healthcare environments require continuous, automated threat detection and centralized posture management to maintain HIPAA and NIST CSF compliance.

`TITANOPS-133` provisions **AWS GuardDuty with EKS Protection** and **AWS Security Hub**, providing intelligent ML-driven anomaly detection across control plane Kubernetes audit logs and benchmark compliance against standard frameworks.

---

## 2. Infrastructure as Code (Terraform)

Located in `terraform/modules/guardduty_securityhub/`:
- **AWS GuardDuty (`aws_guardduty_detector.primary`)**:
  - `enable = true`: Activates managed threat intelligence feeds.
  - `finding_publishing_frequency = "FIFTEEN_MINUTES"`: Real-time alerting cadence.
  - **EKS Protection**:
    - `datasources.kubernetes.audit_logs.enable = true`: Consumes Amazon EKS audit log streams directly to detect API anomalies, privileged pod executions, anomalous role bindings, and cluster reconnaissance.
- **AWS Security Hub (`aws_securityhub_account.primary`)**:
  - Central security posture management consolidating findings across GuardDuty, AWS WAF, IAM Access Analyzer, and CloudTrail.
  - `auto_enable_controls = true`: Ensures newly released CIS and AWS rules are applied automatically.
- **Security Standards Subscriptions**:
  1. **AWS Foundational Security Best Practices (FSBP) v1.0.0**: Enforces curated security controls across IAM, KMS, S3, RDS, and EKS.
  2. **CIS AWS Foundations Benchmark v1.2.0**: Validates regulatory compliance against industry-standard hardening benchmarks.

---

## 3. Threat Detection Coverage Matrix

| Threat Category | Example Finding Type | Detection Mechanism | Severity |
| :--- | :--- | :--- | :--- |
| **Privilege Escalation** | `Policy:Kubernetes/AdminClusterRoleBinding` | EKS Audit Log stream parsing | **High** (7.0 - 8.9) |
| **Credential Abuse** | `CredentialAccess:Kubernetes/SuccessfulAnonymousAuth` | Audit API authentication monitoring | **Medium** (4.0 - 6.9) |
| **Cryptomining / Malicious Binary** | `Execution:Kubernetes/ExecInPrivilegedPod` | Kubernetes runtime inspection | **High** (7.0 - 8.9) |
| **Cluster Reconnaissance** | `Discovery:Kubernetes/SuccessfulAnonymousAuth` | EKS endpoint probe analysis | **Medium** (4.0 - 6.9) |

---

## 4. Verification

The automated verification suite in `scripts/test-guardduty-securityhub.sh` validates:
- Terraform module validation (`terraform validate`).
- GuardDuty detector resource configuration with EKS audit log datasource.
- Security Hub enablement and standards subscriptions (FSBP and CIS).
- Schema conformity and detection logic for simulated EKS threat findings.

Execution:
```bash
./scripts/test-guardduty-securityhub.sh
```
All 7 automated verification checks pass.
