variable "release_name" { type = string }
variable "chart_path" { type = string }
variable "values_file" { type = string }
variable "namespace" {
  type    = string
  default = "hms"
}
variable "overrides" {
  type    = map(string)
  default = {}
}
variable "wait" {
  type    = bool
  default = true
}
variable "timeout" {
  type    = number
  default = 300
}
variable "atomic" {
  type    = bool
  default = false
}
