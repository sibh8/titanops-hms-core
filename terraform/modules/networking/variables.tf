variable "project_name" {
  description = "Project name used for resource naming and cost tracking"
  type        = string
  default     = "titanops"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs across two Availability Zones"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs across two Availability Zones"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "admin_cidr" {
  description = "Trusted administrator IPv4 CIDR allowed to SSH to EC2"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "Provide a valid IPv4 CIDR, preferably your public IP with /32."
  }
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for private subnet outbound connectivity"
  type        = bool
  default     = false
}