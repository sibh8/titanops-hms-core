output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "Availability Zones used by the network"
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = aws_route_table.private[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "bastion_security_group_id" {
  description = "Security group ID for administrative EC2"
  value       = aws_security_group.bastion.id
}

output "eks_cluster_security_group_id" {
  description = "Additional EKS cluster security group ID"
  value       = aws_security_group.eks_cluster.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID, or null if disabled"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}
