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

variable "alert_email" {
  type        = string
  description = "Notification email address for high-severity security alerts"
  default     = "devops-alerts@titanops.io"
}
