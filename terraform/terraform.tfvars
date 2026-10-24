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
