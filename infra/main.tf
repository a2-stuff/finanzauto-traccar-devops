locals {
  prefix = "avl-${var.environment}"
}

module "secrets" {
  source      = "./modules/secrets"
  prefix      = local.prefix
  environment = var.environment
}

module "database" {
  source                  = "./modules/database"
  prefix                  = local.prefix
  environment             = var.environment
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  master_password         = module.secrets.db_password
  backup_retention_days   = var.enable_backups ? var.backup_retention_days : 0
  storage_encrypted       = var.environment == "prod"
}

module "service" {
  source                     = "./modules/service"
  prefix                     = local.prefix
  environment                = var.environment
  image                      = var.image
  cpu                        = var.ecs_cpu
  memory                     = var.ecs_memory
  host_web_port              = var.host_web_port
  host_osmand_port           = var.host_osmand_port
  db_host                    = module.database.address
  db_port                    = module.database.port
  db_name                    = module.database.db_name
  db_username                = module.database.username
  db_secret_arn              = module.secrets.db_secret_arn
  aws_endpoint_for_tasks     = var.aws_endpoint
  log_retention_days         = var.log_retention_days
}

module "observability" {
  source             = "./modules/observability"
  prefix             = local.prefix
  environment        = var.environment
  log_group_name     = module.service.log_group_name
  log_retention_days = var.log_retention_days
}

module "backup" {
  source      = "./modules/backup"
  prefix      = local.prefix
  environment = var.environment
  enabled     = var.enable_backups
}
