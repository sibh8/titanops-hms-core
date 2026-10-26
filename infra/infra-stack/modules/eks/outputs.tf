output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_ca" { value = aws_eks_cluster.this.certificate_authority[0].data }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.this.arn }
output "oidc_provider_url" { value = aws_iam_openid_connect_provider.this.url }

output "spot_node_group_arn" {
  description = "ARN of the Spot EKS node group"
  value       = var.enable_spot_node_group ? aws_eks_node_group.spot[0].arn : null
}

output "spot_node_group_status" {
  description = "Status of the Spot EKS node group"
  value       = var.enable_spot_node_group ? aws_eks_node_group.spot[0].status : null
}

output "cluster_autoscaler_role_arn" {
  description = "IAM Role ARN for Cluster Autoscaler (IRSA)"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

