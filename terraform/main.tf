# ==============================================================================
# TitanOps HMS: Main Terraform Configuration
# ==============================================================================

module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  admin_cidr           = var.admin_cidr
  enable_nat_gateway   = var.enable_nat_gateway
}

module "eks" {
  source = "./modules/eks"

  project_name              = var.project_name
  environment               = var.environment
  cluster_name              = var.cluster_name
  kubernetes_version        = var.kubernetes_version
  private_subnet_ids        = module.networking.private_subnet_ids
  cluster_security_group_id = module.networking.eks_cluster_security_group_id
  node_instance_type        = var.node_instance_type
  node_desired_size         = var.node_desired_size
  node_min_size             = var.node_min_size
  node_max_size             = var.node_max_size
  admin_cidr                = var.admin_cidr

  # EKS API Server Endpoint Restrictions (TITANOPS-121)
  endpoint_private_access = var.eks_endpoint_private_access
  endpoint_public_access  = var.eks_endpoint_public_access
  public_access_cidrs     = var.eks_public_access_cidrs
}

module "bastion" {
  source = "./modules/bastion"

  project_name      = var.project_name
  environment       = var.environment
  subnet_id         = module.networking.private_subnet_ids[0]
  security_group_id = module.networking.bastion_security_group_id
  instance_type     = var.bastion_instance_type
}

# ------------------------------------------------------------------------------
# AWS RDS MySQL Multi-AZ & KMS-Encrypted (TITANOPS-118)
# ------------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name                  = var.project_name
  environment                   = var.environment
  vpc_id                        = module.networking.vpc_id
  private_subnet_ids            = module.networking.private_subnet_ids
  eks_cluster_security_group_id = module.networking.eks_cluster_security_group_id
  bastion_security_group_id     = module.networking.bastion_security_group_id
  database_name                 = var.database_name
  admin_username                = var.database_username
  admin_password                = var.database_password
  allocated_storage             = var.rds_allocated_storage
  max_allocated_storage         = var.rds_max_allocated_storage
  instance_class                = var.rds_instance_class
  mysql_version                 = var.rds_mysql_version
  multi_az                      = var.rds_multi_az
  backup_retention_period       = var.rds_backup_retention_period
  skip_final_snapshot           = var.rds_skip_final_snapshot
}

# ------------------------------------------------------------------------------
# IAM Roles for Service Accounts - IRSA (TITANOPS-120)
# ------------------------------------------------------------------------------
module "irsa" {
  source = "./modules/irsa"

  project_name        = var.project_name
  environment         = var.environment
  namespace           = var.kubernetes_namespace
  eks_oidc_issuer_url = module.eks.oidc_issuer
  aws_region          = var.aws_region
}

# ------------------------------------------------------------------------------
# AWS ECR Repositories for 10 Services (TITANOPS-68)
# ------------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# ------------------------------------------------------------------------------
# CloudTrail Security & Audit Trail (TITANOPS-122)
# ------------------------------------------------------------------------------
module "cloudtrail" {
  source = "./modules/cloudtrail"

  project_name = var.project_name
  environment  = var.environment
}


