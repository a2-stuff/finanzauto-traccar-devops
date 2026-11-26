output "db_password" {
  value       = random_password.db.result
  sensitive   = true
  description = "Contrasena generada. Solo para inyectar en RDS y en el secreto; no se imprime."
}

output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db.arn
  description = "ARN del secreto en Secrets Manager."
}

output "db_secret_ssm_name" {
  value       = aws_ssm_parameter.db_secret_arn.name
  description = "Parametro SSM con el ARN del secreto."
}
