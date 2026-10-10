# Reusable per-service deploy. Renders the titanops-base chart with a
# Helm-values-compatible app-config YAML. Caller gates with count for enable/disable.
resource "helm_release" "svc" {
  name             = var.release_name
  chart            = var.chart_path
  namespace        = var.namespace
  create_namespace = true
  wait             = var.wait
  timeout          = var.timeout
  atomic           = var.atomic

  # The app-config/<service>.yaml file - identical shape to helm/values/*.yaml
  values = [file(var.values_file)]

  # Stack-level overrides merged on top (e.g. RDS endpoint, image registry).
  dynamic "set" {
    for_each = var.overrides
    content {
      name  = set.key
      value = set.value
    }
  }
}
