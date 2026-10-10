variable "name" { type = string }
variable "k8s_version" {
  type    = string
  default = "1.30"
}
variable "subnet_ids" { type = list(string) }
variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
variable "endpoint_public_access" {
  type    = bool
  default = false
}
variable "node_instance_type" {
  type    = string
  default = "m5.large"
}
variable "node_desired" {
  type    = number
  default = 2
}
variable "node_min" {
  type    = number
  default = 2
}
variable "node_max" {
  type    = number
  default = 4
}
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "log_retention" {
  type    = number
  default = 365
}
variable "tags" {
  type    = map(string)
  default = {}
}
