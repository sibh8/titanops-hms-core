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

variable "enable_spot_node_group" {
  description = "Enable Spot instance node group for stateless and burstable workloads"
  type        = bool
  default     = true
}

variable "spot_instance_types" {
  description = "Diversified instance types for Spot node group to avoid pool exhaustion"
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
}

variable "spot_desired" {
  description = "Desired number of worker nodes in Spot node group"
  type        = number
  default     = 2
}

variable "spot_min" {
  description = "Minimum number of worker nodes in Spot node group"
  type        = number
  default     = 1
}

variable "spot_max" {
  description = "Maximum number of worker nodes in Spot node group"
  type        = number
  default     = 8
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler IRSA role, policy, and node group discovery tags"
  type        = bool
  default     = true
}

