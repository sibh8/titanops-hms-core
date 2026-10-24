terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.60" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.31" }
    helm       = { source = "hashicorp/helm", version = "~> 2.14" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }

  # CIS / TITANOPS-29: remote state in encrypted, versioned, locked S3 with DynamoDB locking.
  backend "s3" {
    bucket         = "titanops-hms-tfstate"
    key            = "hms-core/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "titanops-hms-tflock"
    encrypt        = true
  }
}

