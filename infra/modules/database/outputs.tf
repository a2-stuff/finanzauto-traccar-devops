# El atributo port declarado en el recurso es 5432 (el de PostgreSQL
# dentro del contenedor). Floci publica un puerto proxy distinto
# (7001/7002/7003) en el Endpoint de la API. Lo leemos en vivo para
# que JDBC y pg_dump no apunten a 172.17.0.2:5432 (el proceso de Floci).
data "aws_db_instance" "live" {
  db_instance_identifier = aws_db_instance.this.identifier
}

output "address" {
  value       = data.aws_db_instance.live.address
  description = "Hostname o IP real del endpoint RDS que reporta la API de Floci."
}

output "port" {
  value       = tonumber(element(split(":", data.aws_db_instance.live.endpoint), 1))
  description = "Puerto real del endpoint RDS (proxy de Floci, no el 5432 declarado)."
}

output "endpoint" {
  value       = data.aws_db_instance.live.endpoint
  description = "Host:puerto real del RDS."
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
