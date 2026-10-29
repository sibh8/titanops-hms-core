# ==============================================================================
# TitanOps HMS: Centralized Logging & Retention Module
# Ticket: TITANOPS-132: Set up centralized log aggregation with retention policy
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  oidc_issuer_clean = replace(var.eks_oidc_issuer_url, "https://", "")
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "Centralized-Logging"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Groups for Container & Application Logs with Defined Retention
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    LogType = "ContainerApplicationLogs"
  })
}

resource "aws_cloudwatch_log_group" "dataplane_logs" {
  name              = "/aws/containerinsights/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    LogType = "DataplaneLogs"
  })
}

resource "aws_cloudwatch_log_group" "host_logs" {
  name              = "/aws/containerinsights/${var.cluster_name}/host"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    LogType = "NodeHostLogs"
  })
}

# ------------------------------------------------------------------------------
# IAM IRSA Role for Fluent Bit Log Shipping Agent
# ------------------------------------------------------------------------------
resource "aws_iam_role" "fluent_bit" {
  name        = "${var.project_name}-${var.environment}-fluentbit-logging-role"
  description = "IRSA role for Fluent Bit daemonset to ship container logs to CloudWatch Logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer_clean}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_clean}:sub" = "system:serviceaccount:amazon-cloudwatch:fluent-bit"
            "${local.oidc_issuer_clean}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name           = "${var.project_name}-${var.environment}-fluentbit-logging-role"
    ServiceAccount = "system:serviceaccount:amazon-cloudwatch:fluent-bit"
  })
}

resource "aws_iam_policy" "fluent_bit" {
  name        = "${var.project_name}-${var.environment}-fluentbit-logging-policy"
  description = "Scoped permissions for Fluent Bit to create log streams and push log events"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogStreaming"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.application_logs.arn}:*",
          "${aws_cloudwatch_log_group.dataplane_logs.arn}:*",
          "${aws_cloudwatch_log_group.host_logs.arn}:*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  role       = aws_iam_role.fluent_bit.name
  policy_arn = aws_iam_policy.fluent_bit.arn
}
