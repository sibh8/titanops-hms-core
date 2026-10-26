# Helm Chart Packaging & Repository Publishing Guide

**Ticket:** TITANOPS-52  
**Status:** In Progress / Implemented  
**Author:** Kaushal Patil (`patilkaushal89@gmail.com`)  
**Target:** AWS ECR (OCI Registry) & Amazon S3 (MediCore HMS)

---

## 1. Executive Summary & Architecture

As part of **TITANOPS-52**, the base Helm chart (`helm/titanops-base`) is packaged into versioned, immutable OCI artifacts and published to centralized chart repositories. This decouples chart distribution from local git repository checkouts, allowing pipeline deployments, multi-cluster installations, and third-party consumers to install or upgrade MediCore microservices directly from a remote repository.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Source Helm Chart (helm/titanops-base/)                  │
│    - Chart.yaml (v2), templates/, values.yaml               │
└──────────────────────────────┬──────────────────────────────┘
                               │ (helm package --version <semver>)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Versioned Tarball & Digest                               │
│    - dist/helm/titanops-base-0.1.0.tgz                      │
│    - dist/helm/titanops-base-0.1.0.tgz.sha256               │
└──────────────────────────────┬──────────────────────────────┘
                               │
               ┌───────────────┴───────────────┐
               ▼ (helm push)                   ▼ (aws s3 sync + helm repo index)
┌──────────────────────────────┐┌──────────────────────────────┐
│ Primary: AWS ECR (OCI)       ││ Secondary: AWS S3 Repo       │
│ oci://<account>.dkr.ecr...   ││ s3://titanops-helm-charts    │
└──────────────┬───────────────┘└──────────────┬───────────────┘
               │                               │
               └───────────────┬───────────────┘
                               │ (helm install from remote URI)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Target Kubernetes / Amazon EKS Cluster                   │
│    - Direct install with zero local chart files             │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Definition of Done Compliance Matrix

| Definition of Done Criterion | Status | Implementation Details |
| :--- | :---: | :--- |
| **1. Chart is packaged with a semantic version** | **Compliant** | Packaged via `helm/publish-chart.sh` enforcing SemVer 2.0.0 (`MAJOR.MINOR.PATCH`). Verified across multiple semantic tags (`0.1.0`, `0.1.1`, `1.0.0`) with SHA256 integrity checksums. |
| **2. Chart is pushed to and retrievable from repository (OCI/ECR or S3)** | **Compliant** | Implemented automated push and pull for both AWS ECR (`oci://`) and Amazon S3. Pull retrieval verified with SHA256 byte-for-byte digest match against original archive. |
| **3. `helm install` from the published chart (not local files) succeeds** | **Compliant** | Verified direct execution of `helm install <name> oci://<registry>/... --version <ver> --dry-run` without local chart directory references. Tested standalone and layered with service values (`helm/values/<service>.yaml`). |

---

## 3. Tooling & Automation Components

### 3.1. Unified Publishing Script: `helm/publish-chart.sh`
A robust Bash script providing end-to-end packaging and publication:
- **Semantic Version Validation**: Enforces SemVer 2.0.0 compliance regex.
- **Pre-flight Linting**: Automatically runs `helm lint helm/titanops-base`.
- **Integrity Checksums**: Computes SHA-256 digests (`.sha256`).
- **AWS ECR OCI Push**: Handles automated token acquisition via `aws ecr get-login-password` and executes `helm push`.
- **AWS S3 Repository Publishing**: Generates/merges `index.yaml` via `helm repo index` and uploads archives to S3.
- **Remote Verification**: Supports `--verify` to immediately pull and dry-run install the published remote artifact.

### 3.2. Built-in OCI Test Registry: `helm/test-oci-registry.py`
A zero-dependency Python 3 HTTP server implementing the OCI Distribution Specification (v1.0/v2.0) for offline development and local CI environments:
- Handles standard endpoints: `/v2/`, `/v2/<repo>/blobs/uploads/`, `/v2/<repo>/manifests/<tag>`, `/v2/<repo>/blobs/<digest>`.
- Enables complete local testing of `helm push`, `helm pull`, `helm show chart`, and `helm install` over `oci://localhost:<port>/...`.

### 3.3. Automated Verification Suite: `helm/verify-packaging.sh`
An automated 29-test test suite organized across 8 test suites:
1. **Chart Metadata & SemVer**: Validates `Chart.yaml` fields and SemVer format.
2. **Chart Linting**: Confirms template syntax.
3. **Semantic Version Packaging**: Verifies generation of multiple semantic versions (`0.1.0`, `0.1.1`, `1.0.0`).
4. **Archive Integrity**: Confirms inner tarball directory structure (`templates/`, `values.yaml`, `Chart.yaml`).
5. **OCI Publishing & Pull**: Validates end-to-end OCI push, pull, and SHA256 integrity match.
6. **Remote Chart Inspection**: Tests `helm show chart` and `helm show values` directly from OCI.
7. **Direct OCI Installation (DoD #3)**: Executes `helm install --dry-run` directly from `oci://` without local files.
8. **S3 Indexing**: Tests `helm repo index` and index URL validation.

### 3.4. Continuous Integration Workflow: `.github/workflows/helm-publish-ci.yml`
Automated GitHub Actions pipeline:
- Validates packaging and executes `helm/verify-packaging.sh` on every pull request and push touching `helm/**`.
- On merge to `main` or manual `workflow_dispatch`, authenticates via AWS OIDC, packages with semantic version, and pushes to AWS ECR (`oci://${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/titanops-base`).

---

## 4. Usage Instructions

### 4.1. Packaging & Publishing to AWS ECR (OCI)

1. Authenticate with AWS and publish:
   ```bash
   ./helm/publish-chart.sh \
     --target oci \
     --registry 111122223333.dkr.ecr.ap-south-1.amazonaws.com \
     --repo titanops-base \
     --version 0.1.0 \
     --verify
   ```

2. Inspect remote chart without downloading:
   ```bash
   helm show chart oci://111122223333.dkr.ecr.ap-south-1.amazonaws.com/titanops-base --version 0.1.0
   ```

3. Deploy microservices directly from the published ECR chart:
   ```bash
   helm upgrade --install appointment-service \
     oci://111122223333.dkr.ecr.ap-south-1.amazonaws.com/titanops-base \
     --version 0.1.0 \
     --namespace hms-prod \
     --create-namespace \
     --values helm/values/appointment-service.yaml \
     --values helm/values-prod.yaml
   ```
   *(Notice that no local `helm/titanops-base` directory is referenced)*.

---

### 4.2. Publishing to AWS S3-Backed Repository

1. Package and upload to S3:
   ```bash
   ./helm/publish-chart.sh \
     --target s3 \
     --registry s3://titanops-helm-charts \
     --version 0.1.0 \
     --verify
   ```

2. Add S3 repository and install:
   ```bash
   helm repo add titanops-s3 s3://titanops-helm-charts/charts
   helm repo update
   helm install appointment-service titanops-s3/titanops-base --version 0.1.0
   ```

---

### 4.3. Local Offline Verification

To run the automated 29-test verification suite locally:
```bash
chmod +x helm/verify-packaging.sh
./helm/verify-packaging.sh
```
Output:
```text
======================================================================
 TITANOPS-52: Helm Packaging & Publishing Verification Suite
 Target Chart : .../helm/titanops-base
======================================================================
...
======================================================================
 Verification Complete: 29 passed, 0 failed
======================================================================
```
