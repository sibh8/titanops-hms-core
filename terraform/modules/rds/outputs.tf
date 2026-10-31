# ==============================================================================
# TitanOps HMS: RDS MySQL Module Outputs - TITANOPS-118
# All outputs return empty/placeholder values when enable_rds = false.
# ==============================================================================

locals {
  mysql_in_cluster_endpoint = "mysql.hms.svc.cluster.local:3306"
}

output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = var.enable_rds ? aws_db_instance.this[0].id : "in-cluster-mysql"
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = var.enable_rds ? aws_db_instance.this[0].arn : ""
}

output "db_endpoint" {
  description = "Connection endpoint for RDS MySQL (or in-cluster MySQL service when RDS is disabled)"
  value       = var.enable_rds ? aws_db_instance.this[0].endpoint : local.mysql_in_cluster_endpoint
}

output "db_address" {
  description = "Hostname of the RDS MySQL instance"
  value       = var.enable_rds ? aws_db_instance.this[0].address : "mysql.hms.svc.cluster.local"
}

output "db_port" {
  description = "Database connection port"
  value       = var.enable_rds ? aws_db_instance.this[0].port : 3306
}

output "db_name" {
  description = "Database name"
  value       = var.enable_rds ? aws_db_instance.this[0].db_name : var.database_name
}

output "db_security_group_id" {
  description = "Security group ID attached to RDS MySQL (empty when RDS is disabled)"
  value       = var.enable_rds ? aws_security_group.rds[0].id : ""
}

output "kms_key_arn" {
  description = "KMS Customer Managed Key ARN used for RDS storage encryption (empty when RDS is disabled)"
  value       = var.enable_rds ? aws_kms_key.rds[0].arn : ""
}

output "kms_key_id" {
  description = "KMS Customer Managed Key ID used for RDS storage encryption (empty when RDS is disabled)"
  value       = var.enable_rds ? aws_kms_key.rds[0].key_id : ""
}

output "multi_az_enabled" {
  description = "Whether Multi-AZ redundancy is active on the database instance"
  value       = var.enable_rds ? aws_db_instance.this[0].multi_az : false
}

output "jdbc_connection_url" {
  description = "JDBC connection URL for Spring Boot microservices datasource configuration"
  value       = var.enable_rds ? "jdbc:mysql://${aws_db_instance.this[0].endpoint}/${aws_db_instance.this[0].db_name}?useSSL=true&requireSSL=true&verifyServerCertificate=false&allowPublicKeyRetrieval=true" : "jdbc:mysql://${local.mysql_in_cluster_endpoint}/${var.database_name}?useSSL=false&allowPublicKeyRetrieval=true"
}

