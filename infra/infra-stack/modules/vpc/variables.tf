variable "name" { type = string }
variable "cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "private_app_subnets" { type = list(string) }
variable "private_db_subnets" { type = list(string) }
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "flow_log_retention" {
  type    = number
  default = 365
}
variable "tags" {
  type    = map(string)
  default = {}
}
