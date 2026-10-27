# ==============================================================================
# TitanOps HMS: IRSA Module Variables - TITANOPS-120
# ==============================================================================

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "titanops"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "namespace" {
  description = "Kubernetes namespace where service accounts are deployed"
  type        = string
  default     = "titanops"
}

variable "eks_oidc_issuer_url" {
  description = "The OIDC issuer URL from the EKS cluster (e.g. aws_eks_cluster.this.identity[0].oidc[0].issuer)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for scoped IAM policy resources"
  type        = string
  default     = "ap-south-1"
}
