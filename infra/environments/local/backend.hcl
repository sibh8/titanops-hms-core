# Backend configuration for LOCAL environment (minikube)
# Usage: terraform init -backend-config=../../environments/local/backend.hcl
bucket         = "titanops-hms-tfstate"
key            = "local/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "titanops-hms-tflock"
encrypt        = true
