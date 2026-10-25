output "namespace" {
  description = "Namespace where Kyverno admission controller is installed"
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name for Kyverno"
  value       = helm_release.kyverno.name
}

output "chart_version" {
  description = "Kyverno Helm chart version"
  value       = var.chart_version
}

output "enforcement_mode" {
  description = "Validation failure action mode"
  value       = var.validation_failure_action
}
