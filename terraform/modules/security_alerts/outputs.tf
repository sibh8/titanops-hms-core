output "security_alerts_sns_topic_arn" {
  description = "ARN of the SNS topic receiving security event alerts"
  value       = aws_sns_topic.security_alerts.arn
}

output "guardduty_event_rule_arn" {
  description = "ARN of the EventBridge rule for GuardDuty security findings"
  value       = aws_cloudwatch_event_rule.guardduty_findings.arn
}

output "auth_failure_alarm_arn" {
  description = "ARN of the CloudWatch Metric Alarm for authentication failures"
  value       = aws_cloudwatch_metric_alarm.auth_failure_spike.arn
}

output "waf_block_alarm_arn" {
  description = "ARN of the CloudWatch Metric Alarm for WAF blocked requests"
  value       = aws_cloudwatch_metric_alarm.waf_block_spike.arn
}
