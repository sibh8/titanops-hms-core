variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "titanops"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
  default     = "titanops-dev-eks"
}

variable "eks_oidc_issuer_url" {
  type        = string
  description = "EKS OIDC issuer URL for Fluent Bit IRSA"
}

variable "log_retention_days" {
  type        = number
  description = "Centralized log retention in days (e.g. 30 days)"
  default     = 30
}
