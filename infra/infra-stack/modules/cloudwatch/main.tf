# CloudWatch log group for app/container logs. Caller gates with count.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/hms/${var.name}/apps"
  retention_in_days = var.retention
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}
