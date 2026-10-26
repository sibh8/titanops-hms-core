variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "project_name" {
  type    = string
  default = "titanops"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}
variable "admin_cidr" {
  description = "Administrator public IPv4 CIDR allowed to reach the EKS public API (use your address with /32)"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Provide a valid, restricted IPv4 CIDR; do not use 0.0.0.0/0."
  }
}
variable "enable_nat_gateway" {
  type    = bool
  default = true
}
variable "cluster_name" {
  type    = string
  default = "titanops-dev-eks"
}
variable "kubernetes_version" {
  type     = string
  default  = null
  nullable = true
}
variable "node_instance_type" {
  description = "EC2 instance type for each EKS managed worker"
  type        = string
  default     = "t3.medium"
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_min_size" {
  type    = number
  default = 1
}
variable "node_max_size" {
  type    = number
  default = 2
}
variable "bastion_instance_type" {
  description = "Small EC2 instance used for private SSM administration"
  type        = string
  default     = "t3.micro"
}
