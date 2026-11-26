resource "aws_kms_key" "ssm" {
  description             = "CMK para el parametro SSM de ${var.environment}."
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowKeyUseInFloci"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "-_"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.prefix}/traccar/db-password"
  description             = "Contrasena de PostgreSQL para Traccar (${var.environment})."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result
}

resource "aws_ssm_parameter" "db_secret_arn" {
  name   = "/${var.prefix}/traccar/db-secret-arn"
  type   = "SecureString"
  key_id = aws_kms_key.ssm.key_id
  value  = aws_secretsmanager_secret.db.arn
}
