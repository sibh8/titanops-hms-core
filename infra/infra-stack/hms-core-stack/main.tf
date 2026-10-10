# ============================================================================
# Infrastructure wiring. AWS modules only run when target=aws (count gating).
# Optional features are gated by local.features.*
# ============================================================================

# ---------- Local target: spin up minikube ----------
module "minikube" {
  count  = local.is_local && local.mk.autostart ? 1 : 0
  source = "../modules/minikube"

  profile            = local.mk.profile
  driver             = local.mk.driver
  cpus               = local.mk.cpus
  memory             = local.mk.memory
  kubernetes_version = local.mk.kubernetes_version
  delete_on_destroy  = local.mk.delete_on_destroy
}

# ---------- AWS core ----------
module "vpc" {
  count  = local.is_aws ? 1 : 0
  source = "../modules/vpc"

  name                = local.name
  cidr                = local.aws_cfg.vpc_cidr
  azs                 = local.aws_cfg.azs
  public_subnets      = local.aws_cfg.public_subnets
  private_app_subnets = local.aws_cfg.private_app_subnets
  private_db_subnets  = local.aws_cfg.private_db_subnets
  tags                = local.tags
}

module "ecr" {
  count  = local.is_aws ? 1 : 0
  source = "../modules/ecr"

  repositories = [for s in keys(local.services) : "${local.name}/${s}"]
  tags         = local.tags
}

module "eks" {
  count  = local.is_aws ? 1 : 0
  source = "../modules/eks"

  name                   = local.name
  k8s_version            = try(local.aws_cfg.k8s_version, "1.30")
  subnet_ids             = module.vpc[0].private_app_subnet_ids
  endpoint_public_access = try(local.aws_cfg.eks_public_access, false)
  public_access_cidrs    = try(local.aws_cfg.eks_public_cidrs, ["0.0.0.0/0"])
  node_instance_type     = try(local.aws_cfg.node_instance_type, "m5.large")
  node_desired           = try(local.aws_cfg.node_desired, 2)
  node_min               = try(local.aws_cfg.node_min, 2)
  node_max               = try(local.aws_cfg.node_max, 4)
  tags                   = local.tags
}

module "rds" {
  count  = local.is_aws ? 1 : 0
  source = "../modules/rds"

  name             = local.name
  vpc_id           = module.vpc[0].vpc_id
  subnet_ids       = module.vpc[0].private_db_subnet_ids
  app_subnet_cidrs = local.aws_cfg.private_app_subnets
  db_name          = local.cfg.database.name
  username         = local.cfg.database.username
  password         = var.db_password
  instance_class   = try(local.cfg.database.instance_class, "db.t3.medium")
  multi_az         = try(local.cfg.database.multi_az, true)
  tags             = local.tags
}

module "iam_oidc" {
  count  = local.is_aws ? 1 : 0
  source = "../modules/iam-oidc"

  name             = local.name
  github_org       = local.cfg.github.org
  github_repo      = local.cfg.github.repo
  allowed_branches = try(local.cfg.github.branches, ["main"])
  tags             = local.tags
}

# ---------- Optional, count-gated features (AWS only) ----------
module "cloudwatch" {
  count  = local.is_aws && local.features.cloudwatch ? 1 : 0
  source = "../modules/cloudwatch"
  name   = local.name
  tags   = local.tags
}

module "guardduty" {
  count  = local.is_aws && local.features.guardduty ? 1 : 0
  source = "../modules/guardduty"
  tags   = local.tags
}

module "security_hub" {
  count  = local.is_aws && local.features.security_hub ? 1 : 0
  source = "../modules/security-hub"
}

module "secrets_manager" {
  count  = local.is_aws && local.features.secrets_manager ? 1 : 0
  source = "../modules/secrets-manager"

  name        = local.name
  db_username = local.cfg.database.username
  db_password = var.db_password
  db_host     = module.rds[0].endpoint
  db_name     = local.cfg.database.name
  tags        = local.tags
}

module "external_secrets" {
  count  = local.features.external_secrets ? 1 : 0
  source = "../modules/external-secrets"
}
