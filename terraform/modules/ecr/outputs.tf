# ==============================================================================
# TitanOps HMS: ECR Module Outputs (TITANOPS-68)
# ==============================================================================

output "repository_urls" {
  description = "Map of service names to ECR repository URLs for CI/CD push/pull"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of service names to ECR repository ARNs for IAM policies"
  value       = { for k, v in aws_ecr_repository.services : k => v.arn }
}

output "repository_registry_ids" {
  description = "Map of service names to AWS account registry IDs"
  value       = { for k, v in aws_ecr_repository.services : k => v.registry_id }
}
