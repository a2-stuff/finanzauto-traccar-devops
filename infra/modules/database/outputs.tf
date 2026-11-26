output "address" {
  value       = aws_db_instance.this.address
  description = "Hostname o IP del endpoint RDS."
}

output "port" {
  value       = aws_db_instance.this.port
  description = "Puerto del endpoint RDS."
}

output "endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "Host:puerto del RDS."
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "username" {
  value = aws_db_instance.this.username
}

output "identifier" {
  value = aws_db_instance.this.identifier
}
