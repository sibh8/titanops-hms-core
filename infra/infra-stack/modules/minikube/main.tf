# Minikube cluster lifecycle via the minikube CLI (no native provider exists).
# Caller gates with count so this only runs for the local target.
resource "null_resource" "minikube" {
  triggers = {
    profile = var.profile
    driver  = var.driver
    cpus    = var.cpus
    memory  = var.memory
    version = var.kubernetes_version
  }

  # Start (or no-op if already running) on create/update
  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = "minikube start --profile ${var.profile} --driver=${var.driver} --cpus=${var.cpus} --memory=${var.memory} --kubernetes-version=${var.kubernetes_version}"
  }

  # Tear down on destroy
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["pwsh", "-Command"]
    command     = self.triggers.profile != "" ? "minikube delete --profile ${self.triggers.profile}" : "echo skip"
  }
}
