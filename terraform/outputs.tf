output "vpc_id" {
  value = module.networking.vpc_id
}
output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}
output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}
output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "eks_node_group_name" {
  value = module.eks.node_group_name
}
output "bastion_instance_id" {
  value = module.bastion.instance_id
}
output "bastion_private_ip" {
  value = module.bastion.private_ip
}
