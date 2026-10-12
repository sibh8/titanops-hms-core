# GitHub Actions OIDC Authentication to AWS & Amazon EKS (TITANOPS-23)

## 1. Overview & Security Rationale

Traditional CI/CD setups store long-lived AWS IAM Access Keys (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) as GitHub Secrets. This introduces significant security risks:
* Credentials can be leaked or exfiltrated.
* Secret rotation is manual and often neglected.
* Static keys do not expire automatically.

To meet **CIS AWS Foundations Benchmarks** and implement the principle of least privilege, TitanOps HMS Core utilizes **OpenID Connect (OIDC) identity federation** between GitHub Actions and AWS IAM.

```
+------------------+         1. Request OIDC Token (JWT)          +-----------------------+
|  GitHub Actions  | -------------------------------------------> | GitHub OIDC Provider  |
|  Runner (Ubuntu) | <------------------------------------------- | (token.actions.github)|
+------------------+             Signed OIDC Token (JWT)          +-----------------------+
        |
        | 2. AssumeRoleWithWebIdentity(Token, RoleARN)
        v
+------------------+         3. Validate Token Signature, aud, sub  +--------------------+
|     AWS STS      | ---------------------------------------------> | AWS IAM OIDC Trust |
| (Security Token) | <--------------------------------------------- |   Policy Check     |
+------------------+             Temporary Credentials             +--------------------+
        |                        (valid for 1 hour)
        v
+------------------+
| Temporary AWS    | ---> Push container images to AWS ECR
| Credentials      | ---> Access Amazon EKS cluster via kubectl / Helm
+------------------+
```

---

## 2. Infrastructure as Code (Terraform)

The OIDC configuration is defined in `infra/infra-stack/modules/iam-oidc/` and wired in `infra/infra-stack/hms-core-stack/main.tf`.

### 2.1 OIDC Identity Provider
* **Provider URL:** `https://token.actions.githubusercontent.com`
* **Client ID:** `sts.amazonaws.com`
* **Thumbprint:** `6938fd4d98bab03faadb97b34396831e3780aea1`

### 2.2 Scoped Trust Policy (Least Privilege)
The IAM role strictly limits who can assume it by inspecting claims inside the JWT:
* **Audience (`aud`):** Must match `sts.amazonaws.com`
* **Subject (`sub`):** Strictly restricted to this specific repository and branch:
  ```
  repo:sibh8/titanops-hms-core:ref:refs/heads/main
  ```
This prevents unauthorized forks or other repositories from assuming the role.

### 2.3 Scoped Permissions Policy
The assumed role only has permissions required for container deployment:
* **Amazon ECR:** `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`, `ecr:InitiateLayerUpload`, `ecr:PutImage`, `ecr:UploadLayerPart`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`.
* **Amazon EKS:** `eks:DescribeCluster`.
* **Kubernetes Cluster Access:** Mapped via modern EKS Access Entries (`aws_eks_access_entry` and `AmazonEKSClusterAdminPolicy`) so the runner can execute `kubectl get nodes` and `helm upgrade`.

---

## 3. GitHub Actions Configuration

### 3.1 Workflow Permissions
Workflows interacting with AWS must include:
```yaml
permissions:
  id-token: write  # Crucial: enables runner to fetch OIDC JWT
  contents: read
```

### 3.2 Action Usage
```yaml
- name: Configure AWS credentials via OIDC
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_OIDC_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION || 'ap-south-1' }}
    audience: sts.amazonaws.com
```

### 3.3 Verification
The `.github/workflows/aws-oidc-verify.yml` workflow tests:
1. `aws sts get-caller-identity` to verify the assumed role ARN.
2. `aws eks update-kubeconfig` and `kubectl get nodes` to confirm cluster management access.

---

## 4. Setup in GitHub Repository

In GitHub: **Settings -> Secrets and variables -> Actions -> Variables**:
* `AWS_OIDC_ROLE_ARN`: `arn:aws:iam::<ACCOUNT_ID>:role/titanops-hms-gha-oidc-role`
* `AWS_REGION`: `ap-south-1`
* `EKS_CLUSTER_NAME`: `titanops-hms`

**No AWS secret access keys are ever stored in GitHub Secrets.**
