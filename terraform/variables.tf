variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
  default     = "titanops"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "titanops-eks"
}

variable "tags" {
  description = "Common tags for all AWS resources"
  type        = map(string)

  default = {
    Project     = "titanops"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}