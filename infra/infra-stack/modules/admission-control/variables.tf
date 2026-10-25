variable "name" {
  description = "Base name for resources"
  type        = string
  default     = "titanops-hms"
}

variable "namespace" {
  description = "Kubernetes namespace for Kyverno admission controller"
  type        = string
  default     = "kyverno"
}

variable "target_namespace" {
  description = "Target application namespace to enforce Pod Security Standards"
  type        = string
  default     = "hms"
}

variable "chart_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.2.6"
}

variable "validation_failure_action" {
  description = "Kyverno policy enforcement mode: Enforce or Audit"
  type        = string
  default     = "Enforce"
}

variable "enforce_pss_restricted" {
  description = "Enforce native Kubernetes Pod Security Admission restricted profile"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
