# AWS provider only meaningful for target=aws; harmless otherwise.
provider "aws" {
  region                      = try(local.aws_cfg.region, "ap-south-1")
  skip_credentials_validation = local.is_local
  skip_requesting_account_id  = local.is_local
  skip_metadata_api_check     = local.is_local
  default_tags {
    tags = local.tags
  }
}

# For target=aws we authenticate to the freshly created EKS cluster.
# For target=local we point at the minikube kube context.
data "aws_eks_cluster_auth" "this" {
  count = local.is_aws ? 1 : 0
  name  = module.eks[0].cluster_name
}

provider "kubernetes" {
  host                   = local.is_aws ? module.eks[0].cluster_endpoint : null
  cluster_ca_certificate = local.is_aws ? base64decode(module.eks[0].cluster_ca) : null
  token                  = local.is_aws ? data.aws_eks_cluster_auth.this[0].token : null

  # local target: use the minikube context from kubeconfig
  config_path    = local.is_local ? "~/.kube/config" : null
  config_context = local.is_local ? local.mk.profile : null
}

provider "helm" {
  kubernetes {
    host                   = local.is_aws ? module.eks[0].cluster_endpoint : null
    cluster_ca_certificate = local.is_aws ? base64decode(module.eks[0].cluster_ca) : null
    token                  = local.is_aws ? data.aws_eks_cluster_auth.this[0].token : null

    config_path    = local.is_local ? "~/.kube/config" : null
    config_context = local.is_local ? local.mk.profile : null
  }
}
