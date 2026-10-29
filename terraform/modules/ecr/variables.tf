# ==============================================================================
# TitanOps HMS: ECR Module Variables (TITANOPS-68)
# ==============================================================================

variable "project_name" {
  description = "Project identifier prefix"
  type        = string
  default     = "titanops"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "repository_names" {
  description = "List of ECR repository names to create for all microservices and frontend"
  type        = list(string)
  default = [
    "medicore/patient-service",
    "medicore/appointment-service",
    "medicore/user-service",
    "medicore/billing-service",
    "medicore/encounter-service",
    "medicore/lab-service",
    "medicore/medication-service",
    "medicore/prescription-service",
    "medicore/provider-service",
    "medicore/frontend"
  ]
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of tagged images to retain before pruning via lifecycle policy"
  type        = number
  default     = 30
}

variable "untagged_retention_days" {
  description = "Number of days before untagged images expire"
  type        = number
  default     = 14
}
