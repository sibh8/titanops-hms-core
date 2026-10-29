# ==============================================================================
# TitanOps HMS: Secrets Manager Module Variables (TITANOPS-127 & TITANOPS-119)
# ==============================================================================

variable "project_name" {
  type    = string
  default = "titanops"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "database_name" {
  type    = string
  default = "medicore_hms"
}

variable "database_username" {
  type    = string
  default = "medicore"
}

variable "database_endpoint" {
  type    = string
  default = "titanops-dev-mysql.cluster-xyz.us-east-1.rds.amazonaws.com:3306"
}

variable "kms_key_id" {
  type        = string
  description = "KMS Customer Managed Key for secrets encryption"
  default     = ""
}

variable "eks_oidc_issuer_url" {
  type        = string
  description = "EKS OIDC issuer URL for External Secrets Operator IRSA"
  default     = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
}

variable "namespace" {
  type    = string
  default = "hms"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "rotation_lambda_arn" {
  type        = string
  description = "ARN of the Lambda function used to rotate Secrets Manager RDS secrets"
  default     = ""
}

variable "rotation_interval_days" {
  type        = number
  description = "Automated rotation interval in days for database credentials"
  default     = 30
}
