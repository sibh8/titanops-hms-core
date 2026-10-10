output "profile" { value = var.profile }
output "ready_trigger" {
  description = "Depend on this to ensure the cluster is up before deploying."
  value       = null_resource.minikube.id
}
