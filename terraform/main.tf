module "networking" {
  source = "./modules/networking"
}

module "eks" {
  source = "./modules/eks"

  cluster_name = var.cluster_name
}

module "bastion" {
  source = "./modules/bastion"
}