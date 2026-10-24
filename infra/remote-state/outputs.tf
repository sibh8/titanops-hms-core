output "bucket_id" {
  description = "Name of the created S3 remote state bucket"
  value       = module.remote_state.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 remote state bucket"
  value       = module.remote_state.bucket_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB state locking table"
  value       = module.remote_state.dynamodb_table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB state locking table"
  value       = module.remote_state.dynamodb_table_arn
}

output "backend_config_hcl" {
  description = "HCL snippet to insert into versions.tf"
  value       = module.remote_state.backend_config_hcl
}

output "logs_bucket_id" {
  description = "Name of the S3 bucket created for access and audit logs"
  value       = module.remote_state.logs_bucket_id
}

output "logs_bucket_arn" {
  description = "ARN of the S3 bucket created for access and audit logs"
  value       = module.remote_state.logs_bucket_arn
}

