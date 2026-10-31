output "certificate_arn" {
  description = "ARN of the ACM TLS certificate for ALB (empty string when ACM TLS is disabled)"
  value       = var.enable_acm_tls ? aws_acm_certificate.alb_tls[0].arn : ""
}

output "load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "load_balancer_controller_role_name" {
  description = "Name of the AWS Load Balancer Controller IRSA role"
  value       = aws_iam_role.aws_load_balancer_controller.name
}
