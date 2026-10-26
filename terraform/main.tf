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
}

module "bastion" {
  source = "./modules/bastion"

  project_name      = var.project_name
  environment       = var.environment
  subnet_id         = module.networking.private_subnet_ids[0]
  security_group_id = module.networking.bastion_security_group_id
  instance_type     = var.bastion_instance_type
}
