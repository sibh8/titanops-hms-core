# Secrets Manager for DB credentials - CIS: KMS encrypted. Caller gates with count.
resource "aws_secretsmanager_secret" "db" {
  name       = "${var.name}/db-credentials"
  kms_key_id = var.kms_key_arn
  tags       = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    dbname   = var.db_name
  })
}
