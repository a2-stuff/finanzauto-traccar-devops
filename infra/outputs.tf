output "environment" {
  value       = var.environment
  description = "Ambiente desplegado."
}

output "web_url" {
  value       = "http://127.0.0.1:${var.host_web_port}"
  description = "URL de la UI de Traccar en este equipo."
}

output "osmand_url" {
  value       = "http://127.0.0.1:${var.host_osmand_port}"
  description = "URL OsmAnd para el simulador GPS."
}

output "db_address" {
  value       = module.database.address
  description = "Host del RDS emulado (sin contrasena)."
}

output "db_port" {
  value       = module.database.port
  description = "Puerto del RDS emulado."
}

output "db_secret_arn" {
  value       = module.secrets.db_secret_arn
  description = "ARN del secreto con la contrasena de la base."
}

output "ecs_cluster_name" {
  value       = module.service.cluster_name
  description = "Nombre del cluster ECS."
}

output "ecs_service_name" {
  value       = module.service.service_name
  description = "Nombre del servicio ECS."
}

output "ecs_task_family" {
  value       = module.service.task_family
  description = "Familia de la task definition."
}

output "log_group_name" {
  value       = module.service.log_group_name
  description = "Grupo de logs de CloudWatch."
}

output "dashboard_name" {
  value       = module.observability.dashboard_name
  description = "Dashboard de CloudWatch (disponibilidad, errores, recursos)."
}

output "alarm_name" {
  value       = module.observability.alarm_name
  description = "Alarma de disponibilidad de Traccar."
}

output "backup_bucket" {
  value       = module.backup.bucket
  description = "Bucket S3 de respaldos (vacio si el ambiente no los habilita)."
}
