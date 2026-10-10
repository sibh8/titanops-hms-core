variable "repositories" { type = list(string) }
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "keep_images" {
  type    = number
  default = 10
}
variable "tags" {
  type    = map(string)
  default = {}
}
