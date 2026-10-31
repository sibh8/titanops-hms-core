# ==============================================================================
# TitanOps HMS: AWS RDS MySQL Module (Multi-AZ, KMS-Encrypted) - TITANOPS-118
# NOTE: All resources are gated by var.enable_rds (default false).
#       RDS is blocked by the AWS Org SCP on account 561789488706.
#       Set enable_rds = true only in an account where RDS is permitted.
#       Use the in-cluster MySQL Helm chart instead (see helm/mysql-values.yaml).
# ==============================================================================

resource "aws_kms_key" "rds" {
  count                   = var.enable_rds ? 1 : 0
  description             = "KMS Customer Managed Key for TitanOps HMS RDS MySQL Storage Encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-kms-key"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "rds" {
  count         = var.enable_rds ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

resource "aws_db_subnet_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.project_name}-${var.environment}-rds-subnet-group"
  description = "Database subnet group spanning private subnets across multiple AZs"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-subnet-group"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for TitanOps HMS RDS MySQL allowing ingress from EKS and Bastion"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow MySQL traffic from EKS worker nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  ingress {
    description     = "Allow MySQL admin traffic from Bastion host"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_db_instance" "this" {
  count          = var.enable_rds ? 1 : 0
  identifier     = "${var.project_name}-${var.environment}-mysql"
  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"

  # High-Availability Multi-AZ (DoD Item 1)
  multi_az = var.multi_az

  # Encryption at rest via AWS KMS (DoD Item 1)
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds[0].arn

  db_name  = var.database_name
  username = var.admin_username
  password = var.admin_password
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.rds[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  backup_retention_period   = var.backup_retention_period
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${var.project_name}-${var.environment}-mysql-final-snapshot"
  deletion_protection       = false

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql"
    Project     = var.project_name
    Environment = var.environment
    Role        = "managed-database"
    ManagedBy   = "Terraform"
  }
}
