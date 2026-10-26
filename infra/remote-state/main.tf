# ==============================================================================
# Standalone Bootstrap Stack for MediCore HMS Terraform Remote State
# ==============================================================================
# Provisions the S3 bucket with versioning and encryption + DynamoDB lock table.
# Run this once prior to initializing hms-core-stack with the S3 backend.
# ==============================================================================

module "remote_state" {
  source = "../infra-stack/modules/remote-state"

  name                = var.name
  region              = var.region
  bucket_name         = var.bucket_name
  dynamodb_table_name = var.dynamodb_table_name

  enable_versioning = true
  enable_encryption = true

  tags = {
    Project     = "MediCore-HMS"
    ManagedBy   = "Terraform"
    Environment = "Shared-Infra"
    Component   = "TerraformState"
  }
}
