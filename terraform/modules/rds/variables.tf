# ==============================================================================
# TitanOps HMS: RDS MySQL Module Variables - TITANOPS-118
# ==============================================================================

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "titanops"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID of the VPC where RDS instance will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs spanning at least two AZs for Multi-AZ RDS"
  type        = list(string)
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS cluster/worker nodes allowed to connect to RDS"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group ID of the bastion host allowed for database administration"
  type        = string
}

variable "database_name" {
  description = "Initial database name to create in RDS MySQL"
  type        = string
  default     = "medicore_hms"
}

variable "admin_username" {
  description = "Master administrator username for RDS MySQL"
  type        = string
  default     = "medicore"
}

variable "admin_password" {
  description = "Master administrator password for RDS MySQL"
  type        = string
  sensitive   = true
  default     = "medicore_pass"
}

variable "allocated_storage" {
  description = "Initial storage allocated for the database in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage limit for auto-scaling in GB"
  type        = number
  default     = 100
}

variable "instance_class" {
  description = "RDS DB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "mysql_version" {
  description = "MySQL database engine version"
  type        = string
  default     = "8.0.35"
}

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ for high availability (TITANOPS-118 DoD)"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Whether to skip creating a final snapshot before database deletion"
  type        = bool
  default     = true
}
