variable "profile" {
  type    = string
  default = "hms-core"
}
variable "driver" {
  type    = string
  default = "docker"
}
variable "cpus" {
  type    = number
  default = 4
}
variable "memory" {
  type    = number
  default = 8192
}
variable "kubernetes_version" {
  type    = string
  default = "stable"
}
variable "delete_on_destroy" {
  type    = bool
  default = true
}
