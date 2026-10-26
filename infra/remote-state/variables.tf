variable "name" {
  description = "Base prefix for remote state resources"
  type        = string
  default     = "titanops-hms"
}

variable "region" {
  description = "AWS region for S3 and DynamoDB"
  type        = string
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "Explicit S3 bucket name (must be globally unique in AWS). Defaults to {name}-tfstate"
  type        = string
  default     = "titanops-hms-tfstate"
}

variable "dynamodb_table_name" {
  description = "Explicit DynamoDB lock table name"
  type        = string
  default     = "titanops-hms-tflock"
}
