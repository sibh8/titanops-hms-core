variable "name" {
  description = "Base prefix name for S3 bucket and DynamoDB table (e.g. titanops-hms)"
  type        = string
  default     = "titanops-hms"
}

variable "region" {
  description = "AWS region for the S3 bucket and DynamoDB lock table"
  type        = string
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "Explicit S3 bucket name. If omitted, defaults to {name}-tfstate"
  type        = string
  default     = null
}

variable "dynamodb_table_name" {
  description = "Explicit DynamoDB lock table name. If omitted, defaults to {name}-tflock"
  type        = string
  default     = null
}

variable "enable_versioning" {
  description = "Enable versioning on the S3 bucket for state history and disaster recovery (DoD #3)"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption with AWS managed key (AES256) or KMS"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Optional KMS Key ARN for S3 and DynamoDB encryption. If null, AES256 / AWS-managed encryption is used"
  type        = string
  default     = null
}

variable "noncurrent_version_retention_days" {
  description = "Number of days before expiring non-current state versions in S3 to optimize cost"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project   = "MediCore-HMS"
    ManagedBy = "Terraform"
    Component = "RemoteState"
  }
}
