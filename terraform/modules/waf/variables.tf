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
