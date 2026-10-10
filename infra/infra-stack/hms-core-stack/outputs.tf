output "target" { value = local.target }
output "deployed_services" { value = keys(local.enabled_services) }

output "region" {
  value = local.is_aws ? try(local.aws_cfg.region, "ap-south-1") : null
}

output "vpc_id" {
  value = local.is_aws ? module.vpc[0].vpc_id : null
}

output "cluster_name" {
  value = local.is_aws ? module.eks[0].cluster_name : null
}

output "rds_identifier" {
  value = local.is_aws ? "${local.name}-mysql" : null
}

output "cluster_endpoint" {
  value     = local.is_aws ? module.eks[0].cluster_endpoint : "minikube:${local.mk.profile}"
  sensitive = true
}

output "ecr_repository_urls" {
  value = local.is_aws ? module.ecr[0].repository_urls : {}
}

output "rds_endpoint" {
  value     = local.is_aws ? module.rds[0].endpoint : "in-cluster:medicore-mysql"
  sensitive = true
}

output "gha_oidc_role_arn" {
  value = local.is_aws ? module.iam_oidc[0].role_arn : null
}

output "enabled_features" {
  value = { for k, v in local.features : k => v if v }
}
