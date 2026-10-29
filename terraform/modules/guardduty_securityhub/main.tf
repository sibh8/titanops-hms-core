# ==============================================================================
# TitanOps HMS: AWS GuardDuty EKS Protection & Security Hub Module
# Ticket: TITANOPS-133: Enable GuardDuty EKS Protection and Security Hub
# ==============================================================================

data "aws_partition" "current" {}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "Threat-Detection-SecurityHub"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# AWS GuardDuty Detector with Kubernetes / EKS Audit Log Protection
# ------------------------------------------------------------------------------
resource "aws_guardduty_detector" "primary" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-guardduty"
  })
}

# ------------------------------------------------------------------------------
# AWS Security Hub Account & Automated Standards Subscriptions
# ------------------------------------------------------------------------------
resource "aws_securityhub_account" "primary" {
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"
}

# Standard 1: AWS Foundational Security Best Practices (FSBP)
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.primary]
}

# Standard 2: CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis_aws_foundations" {
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"

  depends_on = [aws_securityhub_account.primary]
}
