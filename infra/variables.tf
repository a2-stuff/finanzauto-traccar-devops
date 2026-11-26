variable "environment" {
  type        = string
  description = "Nombre del ambiente: dev, uat o prod."

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment debe ser dev, uat o prod."
  }
}

variable "image" {
  type        = string
  description = "Imagen de Traccar a desplegar (etiqueta SHA del commit)."
  default     = "traccar-avl:local"
}

variable "ecs_cpu" {
  type        = number
  description = "CPU de la task de ECS (unidades AWS)."
}

variable "ecs_memory" {
  type        = number
  description = "Memoria de la task de ECS, en MiB."
}

variable "db_instance_class" {
  type        = string
  description = "Clase de la instancia RDS."
}

variable "db_allocated_storage" {
  type        = number
  description = "Almacenamiento RDS en GiB."
}

variable "log_retention_days" {
  type        = number
  description = "Retencion de logs en CloudWatch, en dias."
}

variable "backup_retention_days" {
  type        = number
  description = "Retencion de backups automaticos de RDS, en dias."
}

variable "host_web_port" {
  type        = number
  description = "Puerto del host para la UI de Traccar."
}

variable "host_osmand_port" {
  type        = number
  description = "Puerto del host para el protocolo OsmAnd."
}

variable "enable_backups" {
  type        = bool
  description = "Si es true, se crea el bucket de respaldos y se habilita backup en RDS."
}
