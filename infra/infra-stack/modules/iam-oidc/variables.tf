variable "name" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string }
variable "allowed_branches" {
  type    = list(string)
  default = ["main"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
