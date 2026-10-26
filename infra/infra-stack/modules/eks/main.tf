# EKS module - CIS: audit logging, KMS secret encryption, IMDSv2, private nodes
data "aws_partition" "current" {}

resource "aws_iam_role" "cluster" {
  name = "${var.name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# CIS EKS 3.x: envelope encryption of secrets with KMS
resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # CIS EKS 2.x: control plane logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  dynamic "encryption_config" {
    for_each = var.kms_key_arn == null ? [] : [1]
    content {
      provider { key_arn = var.kms_key_arn }
      resources = ["secrets"]
    }
  }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.eks]
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.log_retention
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

# OIDC provider for IRSA
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

# Node group
resource "aws_iam_role" "node" {
  name = "${var.name}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# CIS: IMDSv2 enforced via launch template
resource "aws_launch_template" "node" {
  name_prefix = "${var.name}-node-"
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name                                    = "${var.name}-node"
        "k8s.io/cluster-autoscaler/enabled"     = "true"
        "k8s.io/cluster-autoscaler/${var.name}" = "owned"
      }
    )
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired
    min_size     = var.node_min
    max_size     = var.node_max
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  tags = merge(
    var.tags,
    {
      "k8s.io/cluster-autoscaler/enabled"     = "true"
      "k8s.io/cluster-autoscaler/${var.name}" = "owned"
    }
  )

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ------------------------------------------------------------------------------
# Spot Node Group for Cost Optimization (stateless & burstable workloads)
# DoD #1: Node groups use Spot instances for non-critical workloads
# ------------------------------------------------------------------------------
resource "aws_launch_template" "spot_node" {
  count       = var.enable_spot_node_group ? 1 : 0
  name_prefix = "${var.name}-spot-node-"
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name                                                                         = "${var.name}-spot-node"
        "k8s.io/cluster-autoscaler/enabled"                                          = "true"
        "k8s.io/cluster-autoscaler/${var.name}"                                      = "owned"
        "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle" = "spot"
        "k8s.io/cluster-autoscaler/node-template/label/capacity"                     = "spot"
        "k8s.io/cluster-autoscaler/node-template/label/workload"                     = "stateless"
      }
    )
  }
}

resource "aws_eks_node_group" "spot" {
  count           = var.enable_spot_node_group ? 1 : 0
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-spot-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  capacity_type   = "SPOT"
  instance_types  = var.spot_instance_types

  scaling_config {
    desired_size = var.spot_desired
    min_size     = var.spot_min
    max_size     = var.spot_max
  }

  labels = {
    "node.kubernetes.io/lifecycle" = "spot"
    "capacity"                     = "spot"
    "workload"                     = "stateless"
  }

  launch_template {
    id      = aws_launch_template.spot_node[0].id
    version = aws_launch_template.spot_node[0].latest_version
  }

  tags = merge(
    var.tags,
    {
      "k8s.io/cluster-autoscaler/enabled"                                          = "true"
      "k8s.io/cluster-autoscaler/${var.name}"                                      = "owned"
      "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle" = "spot"
      "k8s.io/cluster-autoscaler/node-template/label/capacity"                     = "spot"
      "k8s.io/cluster-autoscaler/node-template/label/workload"                     = "stateless"
    }
  )

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ------------------------------------------------------------------------------
# Cluster Autoscaler IAM Role for Service Accounts (IRSA) & Scoped Policy
# DoD #2: Cluster Autoscaler deployed with IAM least privilege
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "cluster_autoscaler" {
  count       = var.enable_cluster_autoscaler ? 1 : 0
  name        = "${var.name}-cluster-autoscaler-policy"
  description = "Least privilege IAM policy for EKS Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ClusterAutoscalerReadPermissions"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "ClusterAutoscalerMutateScopedPermissions"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.name}" = "owned"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  name  = "${var.name}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.this.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count      = var.enable_cluster_autoscaler ? 1 : 0
  role       = aws_iam_role.cluster_autoscaler[0].name
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
}
