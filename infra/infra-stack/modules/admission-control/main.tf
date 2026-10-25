# ==============================================================================
# Admission Control Module: Kyverno & Pod Security Standards (PSS)
# TITANOPS-125: Enforce Pod Security Standards via admission control
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Kyverno Admission Controller via Helm
# DoD #1: Kyverno or OPA Gatekeeper deployed to the cluster
# ------------------------------------------------------------------------------
resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "admissionController.replicas"
    value = "1"
  }

  set {
    name  = "admissionController.container.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "admissionController.container.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "admissionController.container.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "admissionController.container.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "admissionController.container.securityContext.allowPrivilegeEscalation"
    value = "false"
  }

  set {
    name  = "admissionController.container.securityContext.readOnlyRootFilesystem"
    value = "true"
  }

  set {
    name  = "admissionController.podSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "admissionController.podSecurityContext.runAsUser"
    value = "65534"
  }
}

# ------------------------------------------------------------------------------
# 2. Kubernetes Pod Security Admission (PSA) Labels on Application Namespace
# DoD #1 & #2: Defense-in-depth enforcement of PSS Restricted profile
# ------------------------------------------------------------------------------
resource "kubernetes_labels" "pss_namespace" {
  count       = var.enforce_pss_restricted ? 1 : 0
  api_version = "v1"
  kind        = "Namespace"

  metadata {
    name = var.target_namespace
  }

  labels = {
    "pod-security.kubernetes.io/enforce"         = "restricted"
    "pod-security.kubernetes.io/enforce-version" = "latest"
    "pod-security.kubernetes.io/warn"            = "restricted"
    "pod-security.kubernetes.io/warn-version"    = "latest"
    "pod-security.kubernetes.io/audit"           = "restricted"
    "pod-security.kubernetes.io/audit-version"   = "latest"
  }
}
