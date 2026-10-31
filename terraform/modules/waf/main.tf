# ==============================================================================
# TitanOps HMS: AWS WAFv2 WebACL Module for Public ALB Protection
# Ticket: TITANOPS-129: Attach AWS WAF to the public ALB
# ==============================================================================

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "WAFv2"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group for WAF Access & Block Logs
# Must start with 'aws-waf-logs-' prefix per AWS WAFv2 logging requirements
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.project_name}-${var.environment}-alb"
  retention_in_days = 30

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AWS WAFv2 WebACL (Regional scope for ALB)
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "public_alb" {
  name        = "${var.project_name}-${var.environment}-alb-waf"
  description = "WAFv2 WebACL protecting ALB with OWASP and SQLi managed rules"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Common Rule Set (OWASP Top 10 vulnerabilities)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-waf-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Known Bad Inputs Rule Set (Path traversal, command injection)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-waf-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed SQL Injection Rule Set (SQLi injection detection & blocking)
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-waf-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Rate-based Flood / DDoS Protection (Max 2,000 requests per 5 minutes per IP)
  rule {
    name     = "RateLimitPerIP"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-waf-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-alb-waf-metric"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-waf"
  })
}

# ------------------------------------------------------------------------------
# Logging Configuration for Blocked & Monitored Requests
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.public_alb.arn

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      requirement = "MEETS_ANY"
    }
  }
}
