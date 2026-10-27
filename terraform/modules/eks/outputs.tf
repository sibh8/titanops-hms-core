# ==============================================================================
# TitanOps HMS: EKS Module Outputs - TITANOPS-26, 120, 121
# ==============================================================================

output "cluster_id" {
  description = "The EKS cluster ID"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint URL for Amazon EKS API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_issuer" {
  description = "The OpenID Connect identity issuer URL for IRSA (TITANOPS-120)"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_group_name" {
  description = "Name of the managed EKS node group"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN of the EKS worker nodes"
  value       = aws_iam_role.nodes.arn
}

output "endpoint_private_access" {
  description = "Whether private API server endpoint access is enabled (TITANOPS-121)"
  value       = aws_eks_cluster.this.vpc_config[0].endpoint_private_access
}

output "endpoint_public_access" {
  description = "Whether public API server endpoint access is enabled (TITANOPS-121)"
  value       = aws_eks_cluster.this.vpc_config[0].endpoint_public_access
}

output "public_access_cidrs" {
  description = "Allowed CIDR blocks for EKS API server endpoint (TITANOPS-121)"
  value       = aws_eks_cluster.this.vpc_config[0].public_access_cidrs
}
