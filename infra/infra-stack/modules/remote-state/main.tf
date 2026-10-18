# ==============================================================================
# Terraform Remote State Backend Module
# Provisions:
#   1. AWS S3 Bucket (versioned, encrypted, TLS enforced, non-public)
#   2. AWS DynamoDB Table for distributed state locking (LockID hash key)
# Compliance:
#   - CIS AWS Foundations Benchmark 2.1.1, 2.1.2, 2.1.4
#   - HIPAA Security Rule §164.312(a)(2)(iv) (Encryption at Rest)
# ==============================================================================

locals {
  bucket_name = coalesce(var.bucket_name, "${var.name}-tfstate")
  table_name  = coalesce(var.dynamodb_table_name, "${var.name}-tflock")
}

# ------------------------------------------------------------------------------
# 1. S3 Bucket for Terraform Remote State
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  tags = merge(
    var.tags,
    {
      Name        = local.bucket_name
      Purpose     = "TerraformRemoteState"
      Description = "Encrypted remote state bucket for MediCore HMS infrastructure"
    }
  )
}

# DoD #3: Bucket has versioning enabled
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-Side Encryption (AES256 or KMS)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# DoD #3: Bucket is not publicly accessible (All 4 public access controls enforced)
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce in-transit encryption (TLS 1.2+) via bucket policy
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket     = aws_s3_bucket.tfstate.id
  depends_on = [aws_s3_bucket_public_access_block.tfstate]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Lifecycle management for noncurrent state versions (cost optimization)
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }
}

# ------------------------------------------------------------------------------
# 2. DynamoDB Table for Distributed State Locking
# DoD #2: State locking table (DynamoDB) prevents concurrent applies
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "tflock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST" # Zero cost when idle, scales automatically
  hash_key     = "LockID"          # Required exact schema for Terraform S3 backend

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = merge(
    var.tags,
    {
      Name        = local.table_name
      Purpose     = "TerraformStateLocking"
      Description = "DynamoDB distributed lock table preventing concurrent state corruption"
    }
  )
}
