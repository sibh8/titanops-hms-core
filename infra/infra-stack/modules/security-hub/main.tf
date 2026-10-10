# Security Hub + CIS AWS Foundations standard subscription. Caller gates with count.
data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.this]
}
