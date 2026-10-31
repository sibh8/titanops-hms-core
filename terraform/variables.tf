# ==============================================================================
# TitanOps HMS: Root Terraform Variables
# ==============================================================================

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "titanops"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "admin_cidr" {
  description = "Administrator public IPv4 CIDR allowed to reach the EKS public API (use your address with /32)"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Provide a valid, restricted IPv4 CIDR; do not use 0.0.0.0/0."
  }
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

# ------------------------------------------------------------------------------
# EKS Cluster Configuration (TITANOPS-26, TITANOPS-121)
# ------------------------------------------------------------------------------
variable "cluster_name" {
  type    = string
  default = "titanops-dev-eks"
}

variable "kubernetes_version" {
  type     = string
  default  = null
  nullable = true
}

variable "node_instance_type" {
  description = "EC2 instance type for each EKS managed worker"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 2
}

variable "eks_endpoint_private_access" {
  description = "Enable private API server endpoint access (TITANOPS-121)"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access" {
  description = "Enable public API server endpoint access (TITANOPS-121)"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "Explicit CIDR allowlist for EKS public API endpoint (TITANOPS-121)"
  type        = list(string)
  default     = []

  validation {
    condition = length(var.eks_public_access_cidrs) == 0 || (
      alltrue([for cidr in var.eks_public_access_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    )
    error_message = "All eks_public_access_cidrs must be valid restricted IPv4 CIDRs; 0.0.0.0/0 is strictly forbidden."
  }
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for TitanOps HMS applications (TITANOPS-120)"
  type        = string
  default     = "titanops"
}

variable "bastion_instance_type" {
  description = "Small EC2 instance used for private SSM administration"
  type        = string
  default     = "t3.micro"
}

# ------------------------------------------------------------------------------
# RDS MySQL Configuration (TITANOPS-118)
# ------------------------------------------------------------------------------
variable "database_name" {
  description = "Initial database name for TitanOps HMS"
  type        = string
  default     = "medicore_hms"
}

variable "database_username" {
  description = "Master username for RDS MySQL"
  type        = string
  default     = "medicore"
}

variable "database_password" {
  description = "Master password for RDS MySQL"
  type        = string
  sensitive   = true
  default     = "medicore_pass"
}

variable "rds_allocated_storage" {
  description = "Initial storage allocated for RDS in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Max storage allocation for RDS autoscaling in GB"
  type        = number
  default     = 100
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_mysql_version" {
  description = "RDS MySQL engine version"
  type        = string
  default     = "8.0.35"
}

variable "rds_multi_az" {
  description = "Specifies whether RDS is Multi-AZ for high availability (TITANOPS-118 DoD Item 1)"
  type        = bool
  default     = true
}

variable "rds_backup_retention_period" {
  description = "Automated backup retention in days"
  type        = number
  default     = 7
}

variable "rds_skip_final_snapshot" {
  description = "Whether to skip final DB snapshot on destroy"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Feature Flags — disable features blocked by AWS Org SCP or missing resources
# ------------------------------------------------------------------------------
variable "enable_rds" {
  description = "Enable AWS RDS MySQL. Set false (default) when RDS is blocked by SCP; use in-cluster MySQL Helm chart instead."
  type        = bool
  default     = false
}

variable "enable_acm_tls" {
  description = "Enable ACM TLS certificate provisioning via DNS validation. Requires a real registered public domain."
  type        = bool
  default     = false
}

variable "enable_secrets_rotation" {
  description = "Enable Secrets Manager automatic rotation. Requires a deployed rotation Lambda ARN."
  type        = bool
  default     = false
}
