# GuardDuty - CIS detective control. Caller gates with count.
resource "aws_guardduty_detector" "this" {
  enable = true
  tags   = var.tags
}
