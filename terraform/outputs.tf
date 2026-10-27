# ==============================================================================
# TitanOps HMS: Root Terraform Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

# ------------------------------------------------------------------------------
# EKS Cluster & Endpoint Access (TITANOPS-26, TITANOPS-121)
# ------------------------------------------------------------------------------
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_node_group_name" {
  description = "EKS managed node group name"
  value       = module.eks.node_group_name
}

output "eks_oidc_issuer" {
  description = "EKS OIDC issuer URL for IRSA"
  value       = module.eks.oidc_issuer
}

output "eks_endpoint_private_access" {
  description = "Whether EKS private endpoint access is active (TITANOPS-121)"
  value       = module.eks.endpoint_private_access
}

output "eks_endpoint_public_access" {
  description = "Whether EKS public endpoint access is active (TITANOPS-121)"
  value       = module.eks.endpoint_public_access
}

output "eks_public_access_cidrs" {
  description = "EKS public endpoint allowlist CIDRs (TITANOPS-121)"
  value       = module.eks.public_access_cidrs
}

# ------------------------------------------------------------------------------
# Bastion Host
# ------------------------------------------------------------------------------
output "bastion_instance_id" {
  description = "Bastion EC2 instance ID"
  value       = module.bastion.instance_id
}

output "bastion_private_ip" {
  description = "Bastion private IPv4 address"
  value       = module.bastion.private_ip
}

# ------------------------------------------------------------------------------
# RDS MySQL Multi-AZ & KMS-Encrypted (TITANOPS-118)
# ------------------------------------------------------------------------------
output "rds_db_instance_id" {
  description = "RDS DB instance identifier"
  value       = module.rds.db_instance_id
}

output "rds_db_endpoint" {
  description = "Connection endpoint for RDS MySQL"
  value       = module.rds.db_endpoint
}

output "rds_db_address" {
  description = "RDS MySQL hostname address"
  value       = module.rds.db_address
}

output "rds_db_port" {
  description = "RDS MySQL connection port"
  value       = module.rds.db_port
}

output "rds_db_name" {
  description = "RDS MySQL database name"
  value       = module.rds.db_name
}

output "rds_kms_key_arn" {
  description = "KMS Key ARN encrypting RDS storage at rest"
  value       = module.rds.kms_key_arn
}

output "rds_multi_az_enabled" {
  description = "Multi-AZ redundancy status"
  value       = module.rds.multi_az_enabled
}

# ------------------------------------------------------------------------------
# IRSA Service Roles (TITANOPS-120)
# ------------------------------------------------------------------------------
output "irsa_oidc_provider_arn" {
  description = "OIDC Provider ARN used by EKS IRSA"
  value       = module.irsa.oidc_provider_arn
}

output "irsa_service_role_arns" {
  description = "Per-service IAM role ARNs for all 9 microservices"
  value       = module.irsa.service_role_arns
}
