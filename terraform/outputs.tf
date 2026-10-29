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

output "rds_jdbc_connection_url" {
  description = "JDBC connection URL for Spring Boot microservices datasource configuration"
  value       = module.rds.jdbc_connection_url
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

# ------------------------------------------------------------------------------
# ECR Repositories (TITANOPS-68)
# ------------------------------------------------------------------------------
output "ecr_repository_urls" {
  description = "ECR repository URLs for all 10 service images (9 microservices + frontend)"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs for IAM policies"
  value       = module.ecr.repository_arns
}

# ------------------------------------------------------------------------------
# Audit & Compliance Logging (TITANOPS-122)
# ------------------------------------------------------------------------------
output "vpc_flow_log_id" {
  description = "VPC Flow Log ID capturing network traffic"
  value       = module.networking.vpc_flow_log_id
}

output "vpc_flow_log_group_arn" {
  description = "CloudWatch Log Group ARN for VPC Flow Logs"
  value       = module.networking.vpc_flow_log_group_arn
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN for API and management event auditing"
  value       = module.cloudtrail.cloudtrail_arn
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket name archiving CloudTrail audit logs"
  value       = module.cloudtrail.cloudtrail_bucket_name
}

# ------------------------------------------------------------------------------
# AWS Secrets Manager & External Secrets (TITANOPS-127 & TITANOPS-119)
# ------------------------------------------------------------------------------
output "secrets_db_secret_arn" {
  description = "AWS Secrets Manager ARN for database credentials"
  value       = module.secrets.db_secret_arn
}

output "secrets_grafana_secret_arn" {
  description = "AWS Secrets Manager ARN for Grafana credentials"
  value       = module.secrets.grafana_secret_arn
}

output "secrets_external_secrets_role_arn" {
  description = "IAM IRSA Role ARN for External Secrets Operator"
  value       = module.secrets.external_secrets_role_arn
}

# ------------------------------------------------------------------------------
# ALB Ingress & ACM TLS (TITANOPS-128)
# ------------------------------------------------------------------------------
output "acm_certificate_arn" {
  description = "ACM Certificate ARN for ALB HTTPS listener"
  value       = module.ingress.certificate_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM IRSA Role ARN for AWS Load Balancer Controller"
  value       = module.ingress.load_balancer_controller_role_arn
}

# ------------------------------------------------------------------------------
# AWS WAFv2 Protection (TITANOPS-129)
# ------------------------------------------------------------------------------
output "waf_web_acl_arn" {
  description = "ARN of the AWS WAFv2 WebACL attached to ALB"
  value       = module.waf.web_acl_arn
}

output "waf_log_group_arn" {
  description = "ARN of CloudWatch Log Group capturing WAF logs"
  value       = module.waf.log_group_arn
}

# ------------------------------------------------------------------------------
# Centralized Logging (TITANOPS-132)
# ------------------------------------------------------------------------------
output "application_log_group_name" {
  description = "CloudWatch Log Group name for container logs"
  value       = module.logging.application_log_group_name
}

output "application_log_group_arn" {
  description = "CloudWatch Log Group ARN for container logs"
  value       = module.logging.application_log_group_arn
}

output "fluent_bit_role_arn" {
  description = "IAM IRSA Role ARN for Fluent Bit log forwarder"
  value       = module.logging.fluent_bit_role_arn
}

# ------------------------------------------------------------------------------
# Threat Detection & Security Posture (TITANOPS-133)
# ------------------------------------------------------------------------------
output "guardduty_detector_id" {
  description = "GuardDuty Detector ID with EKS Protection enabled"
  value       = module.guardduty_securityhub.guardduty_detector_id
}

output "securityhub_subscription_arn" {
  description = "Security Hub Foundational Best Practices subscription ARN"
  value       = module.guardduty_securityhub.standards_subscription_arn
}







