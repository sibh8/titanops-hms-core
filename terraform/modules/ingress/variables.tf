variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "titanops"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}

variable "eks_oidc_issuer_url" {
  type        = string
  description = "EKS OpenID Connect provider URL"
}

variable "domain_name" {
  type        = string
  description = "Domain name for ACM TLS certificate"
  default     = "titanops.internal"
}

variable "enable_acm_tls" {
  type        = bool
  description = "Enable ACM TLS certificate provisioning. Requires a valid public domain with DNS validation."
  default     = false
}
