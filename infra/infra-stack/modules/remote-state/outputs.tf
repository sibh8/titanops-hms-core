output "bucket_id" {
  description = "Name of the S3 bucket created for Terraform state"
  value       = aws_s3_bucket.tfstate.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket created for Terraform state"
  value       = aws_s3_bucket.tfstate.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table created for state locking"
  value       = aws_dynamodb_table.tflock.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table created for state locking"
  value       = aws_dynamodb_table.tflock.arn
}

output "region" {
  description = "AWS Region hosting the S3 remote state bucket"
  value       = var.region
}

output "logs_bucket_id" {
  description = "Name of the S3 bucket created for access and audit logs"
  value       = var.enable_logging_bucket ? aws_s3_bucket.logs[0].id : null
}

output "logs_bucket_arn" {
  description = "ARN of the S3 bucket created for access and audit logs"
  value       = var.enable_logging_bucket ? aws_s3_bucket.logs[0].arn : null
}

output "backend_config_hcl" {
  description = "Formatted HCL block for Terraform backend configuration in versions.tf"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tfstate.id}"
      key            = "hms-core/terraform.tfstate"
      region         = "${var.region}"
      dynamodb_table = "${aws_dynamodb_table.tflock.name}"
      encrypt        = true
    }
  EOT
}
