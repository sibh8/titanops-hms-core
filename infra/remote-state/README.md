# MediCore HMS — Terraform Remote State Bootstrap

This stack provisions the shared AWS infrastructure required to securely store Terraform state and prevent concurrent modification race conditions:

1. **Amazon S3 Bucket (`titanops-hms-tfstate`)**:
   - **Versioning Enabled**: Retains previous versions of the `.tfstate` file for history, recovery, and audit trails.
   - **Server-Side Encryption**: Encrypted at rest via AES256 or AWS KMS.
   - **Public Access Block**: Strict block on all public ACLs and bucket policies (`block_public_acls = true`, etc.).
   - **In-Transit TLS Enforcement**: Rejects any non-HTTPS requests (`aws:SecureTransport: false`).
   - **Lifecycle Expiration**: Automatically purges non-current versions older than 90 days.

2. **Amazon DynamoDB Table (`titanops-hms-tflock`)**:
   - **Partition Key**: `LockID` (String) required by Terraform S3 backend.
   - **Billing Mode**: `PAY_PER_REQUEST` (On-demand pricing, zero idle cost).
   - **Server-Side Encryption & Point-in-Time Recovery**: Enabled.

---

## Quickstart: Bootstrapping Remote State

### 1. Provision the S3 Bucket and DynamoDB Lock Table
```bash
cd infra/remote-state
terraform init
terraform plan
terraform apply
```

### 2. Configure Backend in Main Stack
Once created, enable the backend in `infra/infra-stack/hms-core-stack/versions.tf`:
```hcl
backend "s3" {
  bucket         = "titanops-hms-tfstate"
  key            = "hms-core/terraform.tfstate"
  region         = "ap-south-1"
  dynamodb_table = "titanops-hms-tflock"
  encrypt        = true
}
```

### 3. Initialize and Migrate State
```bash
cd ../infra-stack/hms-core-stack
terraform init -migrate-state
```
Terraform will prompt:
`Do you want to copy existing state to the new backend? Enter "yes"`
All existing state will be uploaded to S3, and future state operations will use distributed DynamoDB locks!
