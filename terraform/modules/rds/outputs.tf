# ==============================================================================
# TitanOps HMS: RDS MySQL Module Outputs - TITANOPS-118
# ==============================================================================

output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "Connection endpoint for the RDS MySQL instance"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname of the RDS MySQL instance"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Database connection port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "db_security_group_id" {
  description = "Security group ID attached to RDS MySQL"
  value       = aws_security_group.rds.id
}

output "kms_key_arn" {
  description = "KMS Customer Managed Key ARN used for RDS storage encryption at rest"
  value       = aws_kms_key.rds.arn
}

output "kms_key_id" {
  description = "KMS Customer Managed Key ID used for RDS storage encryption at rest"
  value       = aws_kms_key.rds.key_id
}

output "multi_az_enabled" {
  description = "Whether Multi-AZ redundancy is active on the database instance"
  value       = aws_db_instance.this.multi_az
}

output "jdbc_connection_url" {
  description = "Standard JDBC formatted connection URL for Spring Boot microservices"
  value       = "jdbc:mysql://${aws_db_instance.this.endpoint}/${aws_db_instance.this.db_name}?useSSL=true&requireSSL=true&verifyServerCertificate=false&allowPublicKeyRetrieval=true"
}

