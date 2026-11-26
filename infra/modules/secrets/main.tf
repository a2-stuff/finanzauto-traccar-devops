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
  name  = "/${var.prefix}/traccar/db-secret-arn"
  type  = "SecureString"
  value = aws_secretsmanager_secret.db.arn
}
