# ==============================================================================
# TitanOps HMS: CloudTrail Module Variables (TITANOPS-122)
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

variable "retention_days" {
  description = "CloudWatch log retention days for CloudTrail events"
  type        = number
  default     = 90
}

variable "enable_logging" {
  description = "Enables logging for the trail"
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Specifies whether the trail is created in the current region or in all regions"
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Specifies whether the trail is publishing events from global services such as IAM"
  type        = bool
  default     = true
}
