# ==============================================================================
# TitanOps HMS: AWS Secrets Manager & External Secrets Operator IRSA (TITANOPS-127 & TITANOPS-119)
# ==============================================================================

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "grafana_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ------------------------------------------------------------------------------
# Secrets Manager: Database Credentials (with TLS enforced)
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.project_name}/${var.environment}/database"
  description             = "TitanOps HMS RDS MySQL master database credentials"
  kms_key_id              = var.kms_key_id != "" ? var.kms_key_id : null
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-secret"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:mysql://${var.database_endpoint}/${var.database_name}?useSSL=true&requireSSL=true&verifyServerCertificate=true"
    SPRING_DATASOURCE_USERNAME = var.database_username
    SPRING_DATASOURCE_PASSWORD = random_password.db_password.result
  })
}

# ------------------------------------------------------------------------------
# Secrets Manager: Grafana Admin Credentials
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "grafana" {
  name                    = "${var.project_name}/${var.environment}/grafana"
  description             = "TitanOps HMS Grafana administrative credentials"
  kms_key_id              = var.kms_key_id != "" ? var.kms_key_id : null
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-grafana-secret"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    "admin-user"     = "admin"
    "admin-password" = random_password.grafana_password.result
  })
}

# ------------------------------------------------------------------------------
# IAM IRSA Role for External Secrets Operator (ESO)
# ------------------------------------------------------------------------------
locals {
  clean_oidc = replace(var.eks_oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "eso_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::123456789012:oidc-provider/${local.clean_oidc}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.clean_oidc}:sub"
      values   = ["system:serviceaccount:${var.namespace}:external-secrets-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.clean_oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.project_name}-${var.environment}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-external-secrets-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${var.project_name}-${var.environment}-eso-policy"
  description = "Allows External Secrets Operator to retrieve database and grafana secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.database.arn,
          aws_secretsmanager_secret.grafana.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

# ------------------------------------------------------------------------------
# Secrets Manager: Automated Database Credential Rotation (TITANOPS-119)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "db_rotation" {
  name        = "${var.project_name}-${var.environment}-db-secret-rotation-role"
  description = "IAM role for AWS Secrets Manager automated database credential rotation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-secret-rotation-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "db_rotation" {
  name        = "${var.project_name}-${var.environment}-db-secret-rotation-policy"
  description = "Permissions for database credential rotation in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.database.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetRandomPassword"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_rotation" {
  role       = aws_iam_role.db_rotation.name
  policy_arn = aws_iam_policy.db_rotation.arn
}

resource "aws_secretsmanager_secret_rotation" "database" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.database.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_interval_days
  }
}

