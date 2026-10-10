# The ONLY input the operator passes. Everything else comes from config.yaml.
variable "env" {
  type        = string
  description = "Environment name under ../../environments (e.g. dev, local)."
  default     = "local"
}

# DB password is injected at apply time (never stored in YAML/state plaintext).
variable "db_password" {
  type        = string
  description = "Database password. Pass via TF_VAR_db_password or -var."
  sensitive   = true
  default     = "medicore_pass"
}
