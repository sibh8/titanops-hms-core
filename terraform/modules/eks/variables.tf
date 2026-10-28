# ==============================================================================
# TitanOps HMS: EKS Module Variables - TITANOPS-26 & TITANOPS-121
# ==============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type     = string
  default  = null
  nullable = true
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  type = string
}

variable "node_instance_type" {
  type = string
}

variable "node_desired_size" {
  type = number
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "admin_cidr" {
  type = string
}

# ------------------------------------------------------------------------------
# EKS API Server Endpoint Access Restrictions (TITANOPS-121)
# ------------------------------------------------------------------------------
variable "endpoint_private_access" {
  description = "Whether the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of explicit CIDR blocks allowed to reach EKS public endpoint. Must NOT contain 0.0.0.0/0."
  type        = list(string)
  default     = []

  validation {
    condition = length(var.public_access_cidrs) == 0 || (
      alltrue([for cidr in var.public_access_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    )
    error_message = "All public_access_cidrs must be valid, restricted IPv4 CIDR blocks; 0.0.0.0/0 is strictly prohibited for security compliance."
  }
}
