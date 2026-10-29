# Container Image Signing & GitHub Actions SHA Pinning
**Ticket Reference:** `TITANOPS-116`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Locations:** `.github/workflows/*.yml`, `scripts/build-and-push-ecr.sh`

---

## 1. Executive Summary

Supply chain integrity is critical in healthcare and enterprise systems. Two major supply chain attack vectors existed previously:
1. **Floating Action Tags**: CI/CD workflows used mutable major version tags (e.g., `@v4`, `@master`). If an upstream dependency is compromised, arbitrary malicious code could run inside the deployment pipeline with access to production secrets and cloud credentials.
2. **Unsigned Container Images**: Docker images pushed to ECR had no cryptographic proof of origin, opening the cluster to unauthorized image tampering or substitution.

`TITANOPS-116` secures the software supply chain by:
- Pinning **100% of all GitHub Actions** used across 26 workflow files to immutable 40-character commit SHAs.
- Implementing **Sigstore Cosign image signing** for all built microservices and frontend images prior to ECR registration.
- Enforcing **signature verification gating** before deploying any container image into Amazon EKS.

---

## 2. GitHub Actions SHA Pinning Standards

All workflow steps now reference immutable commit hashes with comment annotations denoting upstream releases:

| Action | Pinned Commit SHA | Tag / Release |
| :--- | :--- | :--- |
| `actions/checkout` | `11bd71901bbe5b1630ceea73d27597364c9af683` | `v4.2.2` |
| `actions/setup-java` | `3a4f6e1af504cf6a31855fa8f9c6aaabac41b7b2` | `v4.7.0` |
| `actions/setup-node` | `1e60f620b9541d16bece96c5465dc8ee9832be0b` | `v4.2.0` |
| `actions/setup-python` | `42375524e23c412d93fb67b49958b491fce71c38` | `v5.4.0` |
| `actions/upload-artifact` | `4cec3d8aa04e39d1a68397de0c4cd6fb99ba8afd` | `v4.6.1` |
| `aws-actions/configure-aws-credentials` | `e3ddf1a9912006787b5fce02b6e637d5445b4c65` | `v4.0.2` |
| `aws-actions/amazon-ecr-login` | `062b18b96a7aff071d4dc91bc00c4c1a7945b076` | `v2.0.1` |
| `docker/setup-buildx-action` | `b5ca514318bd6ebac0fb2aedd5d36ec1b5c232a2` | `v3.10.0` |
| `docker/login-action` | `9780b0c442fbb1117ed29e0efdff1e18412f7567` | `v3.3.0` |
| `docker/build-push-action` | `4f58ea79222b3b150c82522db7707f4a74d9b32f` | `v5.4.0` |
| `azure/setup-helm` | `fe7b79cd5ee1e45176fcad797de68ecaf3ca4814` | `v4.3.0` |
| `azure/setup-kubectl` | `3e0aec8d804b37b0c1a90286104d36f538f80470` | `v4.0.0` |
| `hashicorp/setup-terraform` | `b9cd54a3c349d3f38e8881555d616ced269862dd` | `v3.1.2` |
| `aquasecurity/trivy-action` | `18f2510ee396bbf400402947b394f2dd8c87dbb0` | `v0.29.0` |
| `gitleaks/gitleaks-action` | `594e3345377ad5a23f548003f901170966ff9cb4` | `v2.3.4` |
| `sigstore/cosign-installer` | `dc72c7d5c4d10cd6bcb8cf6e3fd625a9e5e537da` | `v3.7.0` |

---

## 3. Cosign Image Signing & Deployment Verification Workflow

```
       ┌───────────────────────────────┐
       │   Docker Build & Push (CI)    │
       │  (Vite Frontend & Spring Boot)│
       └───────────────┬───────────────┘
                       │
                       │ Pushes image to Amazon ECR
                       ▼
       ┌───────────────────────────────┐
       │  Cosign Signing Step          │
       │  cosign sign --yes --key ...  │
       └───────────────┬───────────────┘
                       │
                       │ Attaches OCI signature in ECR
                       ▼
       ┌───────────────────────────────┐
       │  Deployment Pre-Gate (CD)     │
       │  cosign verify --key ...      │
       └───────────────┬───────────────┘
                       │
             ┌─────────┴─────────┐
             │ Signature Valid?  │
             └─────────┬─────────┘
            Yes        │        No
            ▼          │        ▼
┌──────────────────┐   │   ┌───────────────────────────┐
│ Helm Upgrade EKS │   │   │ ABORT: Unverified Image!  │
└──────────────────┘   │   └───────────────────────────┘
```

---

## 4. Verification

The test runner `scripts/test-image-signing-action-shas.sh` validates:
- Audit of all 26 workflow files for zero floating `@v[0-9]+` tags.
- Regular expression verification ensuring 100% of action references use 40-character hex commit SHAs.
- Inclusion of `sigstore/cosign-installer` pinned to commit SHA.
- Cosign image signing steps in `build-and-push-all-ecr.yml` and `reusable-ecr-push.yml`.
- Pre-deployment signature verification gating in `reusable-ecr-push.yml`.
- Cosign signing and verification loops in `scripts/build-and-push-ecr.sh`.
- Cryptographic digital signature generation and verification lifecycle simulation.

Execution:
```bash
./scripts/test-image-signing-action-shas.sh
```
All 8 verification tests pass.
