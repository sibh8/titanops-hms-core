aws_region           = "ap-south-1"
project_name         = "titanops"
environment          = "dev"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Set TF_VAR_admin_cidr to your public IPv4 address with /32 before applying.

enable_nat_gateway    = true
cluster_name          = "titanops-dev-eks"
node_instance_type    = "t3.medium"
node_desired_size     = 2
node_min_size         = 1
node_max_size         = 2
bastion_instance_type = "t3.micro"

# EKS API Access Hardening (TITANOPS-121)
eks_endpoint_private_access = true
eks_endpoint_public_access  = true
eks_public_access_cidrs     = []

# Kubernetes Namespace (TITANOPS-120)
kubernetes_namespace = "titanops"

# AWS RDS Multi-AZ MySQL (TITANOPS-118)
database_name               = "medicore_hms"
database_username           = "medicore"
rds_allocated_storage       = 20
rds_max_allocated_storage   = 100
rds_instance_class          = "db.t3.medium"
rds_mysql_version           = "8.0.35"
rds_multi_az                = true
rds_backup_retention_period = 7
rds_skip_final_snapshot     = true

# Feature flags — disabled because:
# - enable_rds: RDS is blocked by AWS Org SCP (p-h9javrcp) on account 561789488706
# - enable_acm_tls: titanops.internal is not a real public domain; DNS validation cannot succeed
# - enable_secrets_rotation: No rotation Lambda exists; enable after deploying one
enable_rds              = false
enable_acm_tls          = false
enable_secrets_rotation = false
