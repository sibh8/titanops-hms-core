output "guardduty_detector_id" {
  description = "ID of the AWS GuardDuty detector with EKS protection enabled"
  value       = aws_guardduty_detector.primary.id
}

output "guardduty_detector_arn" {
  description = "ARN of the AWS GuardDuty detector"
  value       = aws_guardduty_detector.primary.arn
}

output "securityhub_account_id" {
  description = "Account ID registered with AWS Security Hub"
  value       = aws_securityhub_account.primary.id
}

output "standards_subscription_arn" {
  description = "ARN of the AWS Foundational Security Best Practices subscription"
  value       = aws_securityhub_standards_subscription.aws_foundational.id
}
