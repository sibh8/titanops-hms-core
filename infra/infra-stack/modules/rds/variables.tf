variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "app_subnet_cidrs" { type = list(string) }
variable "engine_version" {
  type    = string
  default = "8.0"
}
variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "db_name" { type = string }
variable "username" { type = string }
variable "password" {
  type      = string
  sensitive = true
}
variable "multi_az" {
  type    = bool
  default = true
}
variable "backup_retention" {
  type    = number
  default = 7
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
