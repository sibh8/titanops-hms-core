variable "namespace" {
  type    = string
  default = "external-secrets"
}
variable "chart_version" {
  type    = string
  default = "0.10.4"
}
variable "service_account_role_arn" {
  type    = string
  default = null
}
