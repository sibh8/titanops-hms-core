# ==============================================================================
# TitanOps HMS: Secrets Manager Module Outputs (TITANOPS-127 & TITANOPS-119)
# ==============================================================================

output "db_secret_id" {
  description = "Secret identifier for RDS MySQL database credentials"
  value       = aws_secretsmanager_secret.database.id
}

output "db_secret_arn" {
  description = "Secret ARN for RDS MySQL database credentials"
  value       = aws_secretsmanager_secret.database.arn
}

output "grafana_secret_id" {
  description = "Secret identifier for Grafana admin credentials"
  value       = aws_secretsmanager_secret.grafana.id
}

output "grafana_secret_arn" {
  description = "Secret ARN for Grafana admin credentials"
  value       = aws_secretsmanager_secret.grafana.arn
}

output "external_secrets_role_arn" {
  description = "IAM IRSA Role ARN assumed by External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "db_secret_rotation_role_arn" {
  description = "IAM Role ARN for AWS Secrets Manager database rotation"
  value       = aws_iam_role.db_rotation.arn
}

