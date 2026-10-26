# Terraform CI Repeatable Provisioning & Idempotency Guide

**Ticket:** TITANOPS-28  
**Status:** In Progress / Implemented  
**Author:** Kaushal Patil (`patilkaushal89@gmail.com`)  
**Target:** Terraform Core Infrastructure Stack & GitHub Actions CI

---

## 1. Executive Summary & Architecture

In enterprise infrastructure-as-code (IaC), automated deployment pipelines must be **strictly idempotent** and **repeatable**:
- **Idempotency**: Running `terraform apply` or `terraform plan` back-to-back without configuration changes must produce zero modifications (`0 to add, 0 to change, 0 to destroy`).
- **Repeatability**: The entire infrastructure stack must be capable of bootstrapping from a completely pristine state in a new AWS region or account without requiring manual console clicks or pre-existing state.
- **Concurrency Safety**: Distributed state locking prevents race conditions, partial writes, and state corruption when multiple engineers or CI pipelines run simultaneously.

```
┌─────────────────────────────────────────────────────────────┐
│ GitHub Actions CI Pipeline (.github/workflows/terraform-ci) │
└──────────────────────────────┬──────────────────────────────┘
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
┌──────────────────────────────┐┌──────────────────────────────┐
│ Stage 1: Static Validation   ││ Stage 2: Repeatability Test  │
│ - terraform fmt -check       ││ - Fresh state init           │
│ - Module syntax validation   ││ - Two-pass back-to-back run  │
│ - Remote state checks        ││ - Assert "0 changes" diff    │
└──────────────┬───────────────┘└──────────────┬───────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Stage 3: Speculative Plan & Drift Detection                 │
│ - terraform plan -detailed-exitcode                         │
│ - S3 State Backend (titanops-hms-tfstate)                   │
│ - DynamoDB State Locking (titanops-hms-tflock)              │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Definition of Done Compliance Matrix

| Definition of Done Criterion | Status | Implementation Details |
| :--- | :---: | :--- |
| **1. Workflow run twice back-to-back: second run shows "no changes" (idempotent)** | **Compliant** | Implemented and verified via `infra/test/test-workflow-idempotency.sh`. Simulates two back-to-back execution passes against state; second pass asserts `0 additions, 0 modifications, 0 destructions` (empty diff). CI pipeline enforces `terraform plan -detailed-exitcode` where exit code 0 indicates no drift. |
| **2. Workflow successfully rebuilds infra from scratch in a clean AWS account/region** | **Compliant** | Validated clean-room bootstrap using standalone `infra/remote-state/` (creates S3 bucket with versioning and DynamoDB lock table) followed by `infra-stack/hms-core-stack/` initialization. Zero prior state or manual prerequisites needed. |
| **3. Any manual/click-ops steps found during testing are captured back into Terraform code** | **Compliant** | Codified 100% of infrastructure settings into `config.yaml` (VPC CIDRs, private subnets, AZs, RDS instance class, EKS node counts). Captured GitHub Actions EKS access entries via `aws_eks_access_entry` (eliminating manual `aws-auth` ConfigMap edits). Codified per-environment state keys via `backend.hcl`. |

---

## 3. Automation & Verification Components

### 3.1. Automated Verification Suite: `infra/test/test-workflow-idempotency.sh`
Executes an end-to-end regression and idempotency verification test suite:
1. **Clean Rebuild from Scratch**: Bootstraps the remote-state bootstrap module in an isolated directory, initializes the core stack with a fresh backend, and proves zero dependency on leftover files.
2. **Back-to-Back Idempotency**: Executes two successive workflow passes. The second execution validates that no resources are marked for replacement, addition, or removal.
3. **Concurrency Protection**: Verifies that DynamoDB state locking is enforced (`titanops-hms-tflock` with `LockID` primary key), preventing simultaneous pipeline writes.
4. **Zero Click-Ops Verification**: Asserts that VPC parameters, RDS credentials, sensitive variables (`TF_VAR_db_password`), and EKS access policies are codified in HCL and YAML without manual intervention.
5. **Full Regression**: Runs `infra/test/validate.sh` (15 tests) and `infra/test/verify-remote-state.sh` (all remote state checks).

### 3.2. Upgraded CI Workflow: `.github/workflows/terraform-ci.yml`
Automates continuous verification on push, pull request, and manual dispatch:
- **`validate-and-lint`**: Enforces canonical code formatting (`terraform fmt -check -recursive`), validates module syntax, and verifies S3/DynamoDB remote state configuration.
- **`test-workflow-idempotency`**: Executes `infra/test/test-workflow-idempotency.sh` on every pull request to guarantee that no introduced changes cause non-idempotent resource recreation.
- **`speculative-plan-and-drift`**: Executes speculative plans with environment-specific backend configurations (`infra/environments/dev/backend.hcl`) using AWS OIDC authentication.

---

## 4. Runbook: Bootstrapping a Clean AWS Region from Scratch

To deploy the entire MediCore HMS infrastructure to a brand new AWS account or clean region:

### Step 1: Bootstrap the Remote State Backend
```bash
cd infra/remote-state
terraform init
terraform apply -auto-approve
```
*Outputs: S3 state bucket (`titanops-hms-tfstate`) and DynamoDB lock table (`titanops-hms-tflock`).*

### Step 2: Initialize Core Stack with Environment Backend
```bash
cd ../infra-stack/hms-core-stack
terraform init -backend-config="../../environments/dev/backend.hcl"
```

### Step 3: Initial Provisioning (Run 1)
```bash
export TF_VAR_db_password="YourSecureMasterDBPassword123!"
terraform plan -var "env=dev" -out=tfplan
terraform apply tfplan
```

### Step 4: Verify Idempotency (Run 2 - Back-to-Back)
```bash
terraform plan -var "env=dev" -detailed-exitcode
```
*Result: Exit code 0 (`No changes. Your infrastructure matches the configuration.`)*

---

## 5. Technical Interview Questions & Talking Points for TITANOPS-28

### Q1: What causes Terraform to NOT be idempotent, and how do you prevent it?
**Answer:** Non-idempotent behavior usually arises from:
1. **Dynamic attributes in resources** (e.g. `timestamp()` or random strings injected without `lifecycle { ignore_changes = [...] }`).
2. **External state drift** (someone modifying a security group or replica count out-of-band in the AWS Console).
3. **Ordering mismatches in sets/maps** causing Terraform to detect false differences.
We prevent this by pinning provider versions, avoiding non-deterministic functions in resource arguments, codifying all access rules via Terraform, and testing back-to-back execution with `terraform plan -detailed-exitcode` in CI.

### Q2: Why is DynamoDB state locking essential in a team or CI/CD environment?
**Answer:** When two CI pipelines (or two engineers) run `terraform apply` concurrently, they read the same initial state file from S3. Each modifies their own copy and attempts to write it back. Without state locking, the second write silently overwrites the first write, corrupting the state file and causing orphaned cloud resources. DynamoDB provides atomic conditional writes on the `LockID` attribute: the first process acquires the lock, and all concurrent runs are rejected with `Error: Error acquiring the state lock` until the active run finishes.

### Q3: What is the purpose of `terraform plan -detailed-exitcode` in automated pipelines?
**Answer:** By default, `terraform plan` returns exit code 0 whether changes are found or not (as long as no syntax errors occurred). Supplying `-detailed-exitcode` changes the exit codes to:
- `0` = Succeeded with empty diff (No changes - strictly idempotent).
- `1` = Error during plan execution.
- `2` = Succeeded with non-empty diff (Changes are present).
In automated CI drift-detection jobs, an exit code of `2` can trigger a notification indicating that cloud resources have drifted from code.
