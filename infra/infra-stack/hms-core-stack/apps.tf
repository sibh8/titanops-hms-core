# ============================================================================
# Deploy each ENABLED service via the reusable helm-service module.
# Disabling a service in config.yaml removes it from this map, so Terraform
# destroys its helm release on the next apply.
# ============================================================================
module "service" {
  for_each = local.enabled_services
  source   = "../modules/helm-service"

  release_name = each.key
  chart_path   = local.chart_path
  values_file  = "${local.app_dir}/${each.key}.yaml"
  namespace    = try(local.cfg.namespace, "hms")
  overrides    = local.svc_overrides

  # On local, wait for minikube to be up first.
  depends_on = [module.minikube, module.eks]
}
