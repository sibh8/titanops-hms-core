variable "name" { type = string }
variable "retention" {
  type    = number
  default = 90
}
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
