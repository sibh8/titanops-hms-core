# ==============================================================================
# TitanOps HMS: Security Event Alerting & EventBridge Module
# Ticket: TITANOPS-134: Add alerting for security events
# ==============================================================================

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "Security-Alerting"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# SNS Topic for Centralized Security Alerts & Incident Response
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_name}-${var.environment}-security-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-security-alerts"
  })
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Sid    = "AllowCloudWatchAlarmsPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# EventBridge Rule: High-Severity GuardDuty Findings Alerting
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.project_name}-${var.environment}-guardduty-high-alerts"
  description = "Routes High and Critical GuardDuty security findings to notification channels"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        7, 7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9,
        8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9
      ]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSecuritySNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# ------------------------------------------------------------------------------
# CloudWatch Metric Alarm: Authentication Failure (HTTP 401/403) Spike
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "auth_failure_spike" {
  alarm_name          = "${var.project_name}-${var.environment}-auth-failure-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Spike in HTTP 401/403 unauthorized client requests (potential credential stuffing attack)"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  ok_actions          = [aws_sns_topic.security_alerts.arn]

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# CloudWatch Metric Alarm: AWS WAF Block Rate Spike
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "waf_block_spike" {
  alarm_name          = "${var.project_name}-${var.environment}-waf-block-rate-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Spike in WAF blocked requests indicates active SQLi, XSS, or flood probe attempt"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    WebACL = "${var.project_name}-${var.environment}-alb-waf"
    Region = "us-east-1"
    Rule   = "ALL"
  }

  tags = local.common_tags
}
