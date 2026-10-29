output "application_log_group_name" {
  description = "Name of the CloudWatch log group for container application logs"
  value       = aws_cloudwatch_log_group.application_logs.name
}

output "application_log_group_arn" {
  description = "ARN of the CloudWatch log group for container application logs"
  value       = aws_cloudwatch_log_group.application_logs.arn
}

output "fluent_bit_role_arn" {
  description = "ARN of the IAM IRSA role for Fluent Bit log shipping agent"
  value       = aws_iam_role.fluent_bit.arn
}
