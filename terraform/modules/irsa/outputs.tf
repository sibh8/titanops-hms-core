# ==============================================================================
# TitanOps HMS: IRSA Module Outputs - TITANOPS-120
# ==============================================================================

output "oidc_provider_arn" {
  description = "The ARN of the EKS OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "The URL of the EKS OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.eks.url
}

output "service_role_arns" {
  description = "Map of microservice name to dedicated IAM role ARN for IRSA"
  value       = { for svc, role in aws_iam_role.service_roles : svc => role.arn }
}

output "billing_role_arn" {
  description = "IRSA IAM role ARN for billing-service"
  value       = aws_iam_role.service_roles["billing-service"].arn
}

output "patient_role_arn" {
  description = "IRSA IAM role ARN for patient-service"
  value       = aws_iam_role.service_roles["patient-service"].arn
}

output "lab_role_arn" {
  description = "IRSA IAM role ARN for lab-service"
  value       = aws_iam_role.service_roles["lab-service"].arn
}

output "prescription_role_arn" {
  description = "IRSA IAM role ARN for prescription-service"
  value       = aws_iam_role.service_roles["prescription-service"].arn
}

output "appointment_role_arn" {
  description = "IRSA IAM role ARN for appointment-service"
  value       = aws_iam_role.service_roles["appointment-service"].arn
}

output "encounter_role_arn" {
  description = "IRSA IAM role ARN for encounter-service"
  value       = aws_iam_role.service_roles["encounter-service"].arn
}

output "medication_role_arn" {
  description = "IRSA IAM role ARN for medication-service"
  value       = aws_iam_role.service_roles["medication-service"].arn
}

output "provider_role_arn" {
  description = "IRSA IAM role ARN for provider-service"
  value       = aws_iam_role.service_roles["provider-service"].arn
}

output "user_role_arn" {
  description = "IRSA IAM role ARN for user-service"
  value       = aws_iam_role.service_roles["user-service"].arn
}
