# ============================================================================
# YAML -> Terraform wrapper. config.yaml is the single source of truth.
# ============================================================================
locals {
  env_dir     = "${path.module}/../../environments/${var.env}"
  config_file = "${local.env_dir}/infra-config/config.yaml"
  app_dir     = "${local.env_dir}/app-config"

  cfg = yamldecode(file(local.config_file))

  target   = local.cfg.target # "aws" | "local"
  is_aws   = local.cfg.target == "aws"
  is_local = local.cfg.target == "local"

  name = local.cfg.name
  tags = try(local.cfg.tags, {})

  # ---- AWS network settings (only used when target=aws) ----
  aws_cfg = try(local.cfg.aws, {})

  # ---- Optional feature switches (count-gated). Default off. ----
  features = merge({
    cloudwatch       = false
    guardduty        = false
    security_hub     = false
    secrets_manager  = false
    external_secrets = false
  }, try(local.cfg.features, {}))

  # ---- Minikube settings (only used when target=local) ----
  mk = merge({
    profile            = "hms-core"
    driver             = "docker"
    cpus               = 4
    memory             = 8192
    kubernetes_version = "stable"
    autostart          = true
    delete_on_destroy  = true
  }, try(local.cfg.minikube, {}))

  # ---- Services: map name -> { enabled } ----
  services         = try(local.cfg.services, {})
  enabled_services = { for k, v in local.services : k => v if try(v.enabled, true) }

  # Helm chart lives in the repo (shared by both targets)
  chart_path = "${path.module}/../../../helm/titanops-base"

  # Stack-level helm overrides, differ per target.
  # On AWS, point datasource at the RDS endpoint; on local keep in-cluster MySQL.
  svc_overrides = local.is_aws ? {
    "env.SPRING_DATASOURCE_URL" = "jdbc:mysql://${try(module.rds[0].endpoint, "")}:3306/${local.cfg.database.name}?useSSL=true&serverTimezone=UTC"
  } : {}
}
