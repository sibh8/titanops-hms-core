# ==============================================================================
# TitanOps HMS: CloudTrail Module Outputs (TITANOPS-122)
# ==============================================================================

output "cloudtrail_id" {
  description = "The name of the trail"
  value       = aws_cloudtrail.main.id
}

output "cloudtrail_arn" {
  description = "The ARN of the trail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_bucket_name" {
  description = "The name of the S3 bucket storing CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_log_group_arn" {
  description = "The CloudWatch Log Group ARN where CloudTrail streams events"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}
