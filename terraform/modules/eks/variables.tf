variable "project_name" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "kubernetes_version" {
  type     = string
  default  = null
  nullable = true
}
variable "private_subnet_ids" { type = list(string) }
variable "cluster_security_group_id" { type = string }
variable "node_instance_type" { type = string }
variable "node_desired_size" { type = number }
variable "node_min_size" { type = number }
variable "node_max_size" { type = number }
variable "admin_cidr" { type = string }
