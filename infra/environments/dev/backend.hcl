# Backend configuration for DEV environment (AWS ap-south-1)
# Usage: terraform init -backend-config=../../environments/dev/backend.hcl
bucket         = "titanops-hms-tfstate"
key            = "dev/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "titanops-hms-tflock"
encrypt        = true
