data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.project_name}-${var.environment}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = length(var.public_access_cidrs) > 0 ? var.public_access_cidrs : [var.admin_cidr]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Control Plane Audit Logging (TITANOPS-122)
  enabled_cluster_log_types = var.cluster_log_types

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${var.project_name}-${var.environment}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "worker_node" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}
resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-node-"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-eks-worker"
      Project     = var.project_name
      Environment = var.environment
      Role        = "eks-worker"
      ManagedBy   = "Terraform"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.project_name}-${var.environment}-eks-worker-volume"
      Project     = var.project_name
      Environment = var.environment
      Role        = "eks-worker"
      ManagedBy   = "Terraform"
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  lifecycle {
    precondition {
      condition = (
        var.node_min_size >= 1 &&
        var.node_min_size <= var.node_desired_size &&
        var.node_desired_size <= var.node_max_size
      )
      error_message = "Node group sizes must satisfy 1 <= min_size <= desired_size <= max_size."
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node,
    aws_iam_role_policy_attachment.ecr_pull,
    aws_iam_role_policy_attachment.cni
  ]
}
