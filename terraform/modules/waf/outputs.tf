output "web_acl_arn" {
  description = "ARN of the AWS WAFv2 WebACL"
  value       = aws_wafv2_web_acl.public_alb.arn
}

output "web_acl_id" {
  description = "ID of the AWS WAFv2 WebACL"
  value       = aws_wafv2_web_acl.public_alb.id
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group capturing WAF logs"
  value       = aws_cloudwatch_log_group.waf_logs.arn
}
