# ==============================================================================
# TitanOps HMS: IAM Roles for Service Accounts (IRSA) Module - TITANOPS-120
# Purpose: Granular, least-privilege pod-level AWS access. Prevents pods from
#          relying on shared EC2 worker node IAM instance profiles.
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Extract TLS certificate thumbprint from EKS OIDC issuer URL
data "tls_certificate" "eks" {
  url = var.eks_oidc_issuer_url
}

locals {
  # OIDC issuer URL without https:// prefix (required for IAM condition keys)
  oidc_issuer_clean = replace(var.eks_oidc_issuer_url, "https://", "")

  # List of 9 microservices requiring dedicated IRSA roles
  services = [
    "patient-service",
    "appointment-service",
    "billing-service",
    "user-service",
    "encounter-service",
    "lab-service",
    "medication-service",
    "prescription-service",
    "provider-service"
  ]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "IRSA"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# EKS OpenID Connect (OIDC) Identity Provider
# ------------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = var.eks_oidc_issuer_url

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-irsa-provider"
  })
}

# ------------------------------------------------------------------------------
# Dedicated IRSA Roles for Each Microservice
# Trust policy strictly validates system:serviceaccount:<namespace>:<service>
# ------------------------------------------------------------------------------
resource "aws_iam_role" "service_roles" {
  for_each = toset(local.services)

  name        = "${var.project_name}-${var.environment}-${each.key}-irsa-role"
  description = "Dedicated IRSA role for Kubernetes ServiceAccount ${var.namespace}/${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_clean}:sub" = "system:serviceaccount:${var.namespace}:${each.key}"
            "${local.oidc_issuer_clean}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name           = "${var.project_name}-${var.environment}-${each.key}-irsa-role"
    Service        = each.key
    ServiceAccount = "system:serviceaccount:${var.namespace}:${each.key}"
  })
}

# ------------------------------------------------------------------------------
# Least-Privilege Scoped Policies per Microservice
# ------------------------------------------------------------------------------

# 1. Billing Service Policy (Invoicing, billing reports, and billing secrets)
resource "aws_iam_policy" "billing" {
  name        = "${var.project_name}-${var.environment}-billing-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS billing-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BillingS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-billing-*",
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-billing-*/*"
        ]
      },
      {
        Sid    = "BillingSecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/billing/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "billing" {
  role       = aws_iam_role.service_roles["billing-service"].name
  policy_arn = aws_iam_policy.billing.arn
}

# 2. Patient Service Policy (Encrypted patient records, demographic docs)
resource "aws_iam_policy" "patient" {
  name        = "${var.project_name}-${var.environment}-patient-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS patient-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PatientRecordsS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-patient-records-*",
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-patient-records-*/*"
        ]
      },
      {
        Sid    = "PatientSecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/patient/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "patient" {
  role       = aws_iam_role.service_roles["patient-service"].name
  policy_arn = aws_iam_policy.patient.arn
}

# 3. Lab Service Policy (Lab results, imaging attachments)
resource "aws_iam_policy" "lab" {
  name        = "${var.project_name}-${var.environment}-lab-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS lab-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LabResultsS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-lab-results-*",
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-lab-results-*/*"
        ]
      },
      {
        Sid      = "LabSecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/lab/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lab" {
  role       = aws_iam_role.service_roles["lab-service"].name
  policy_arn = aws_iam_policy.lab.arn
}

# 4. Prescription Service Policy (Digital prescriptions, pharmacy integrations)
resource "aws_iam_policy" "prescription" {
  name        = "${var.project_name}-${var.environment}-prescription-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS prescription-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PrescriptionS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-prescriptions-*",
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-prescriptions-*/*"
        ]
      },
      {
        Sid      = "PrescriptionSecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/prescription/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "prescription" {
  role       = aws_iam_role.service_roles["prescription-service"].name
  policy_arn = aws_iam_policy.prescription.arn
}

# 5. Appointment Service Policy (Appointment reminders, event publishing)
resource "aws_iam_policy" "appointment" {
  name        = "${var.project_name}-${var.environment}-appointment-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS appointment-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AppointmentSNSAccess"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-appointment-notifications"
      },
      {
        Sid      = "AppointmentSecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/appointment/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "appointment" {
  role       = aws_iam_role.service_roles["appointment-service"].name
  policy_arn = aws_iam_policy.appointment.arn
}

# 6. Encounter Service Policy (Clinical notes, discharge summaries)
resource "aws_iam_policy" "encounter" {
  name        = "${var.project_name}-${var.environment}-encounter-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS encounter-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EncounterS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-encounter-notes-*",
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-encounter-notes-*/*"
        ]
      },
      {
        Sid      = "EncounterSecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/encounter/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "encounter" {
  role       = aws_iam_role.service_roles["encounter-service"].name
  policy_arn = aws_iam_policy.encounter.arn
}

# 7. Medication Service Policy (Medication formulary and interaction service)
resource "aws_iam_policy" "medication" {
  name        = "${var.project_name}-${var.environment}-medication-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS medication-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "MedicationSecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/medication/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "medication" {
  role       = aws_iam_role.service_roles["medication-service"].name
  policy_arn = aws_iam_policy.medication.arn
}

# 8. Provider Service Policy (Doctor/staff profiles and credentials)
resource "aws_iam_policy" "provider" {
  name        = "${var.project_name}-${var.environment}-provider-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS provider-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProviderCredentialsS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-provider-docs-*",
          "arn:${data.aws_partition.current.partition}:s3:::${var.project_name}-${var.environment}-provider-docs-*/*"
        ]
      },
      {
        Sid      = "ProviderSecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/provider/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "provider" {
  role       = aws_iam_role.service_roles["provider-service"].name
  policy_arn = aws_iam_policy.provider.arn
}

# 9. User Service Policy (User auth, RBAC metadata, external IdP tokens)
resource "aws_iam_policy" "user" {
  name        = "${var.project_name}-${var.environment}-user-irsa-policy"
  description = "Least-privilege scoped policy for TitanOps HMS user-service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "UserSecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/user/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "user" {
  role       = aws_iam_role.service_roles["user-service"].name
  policy_arn = aws_iam_policy.user.arn
}
