resource "aws_db_instance" "this" {
  identifier                   = "${var.prefix}-pg"
  engine                       = "postgres"
  engine_version               = "16"
  instance_class               = var.instance_class
  allocated_storage            = var.allocated_storage
  db_name                      = "traccar"
  username                     = "traccar"
  password                     = var.master_password
  port                         = 5432
  publicly_accessible          = true
  skip_final_snapshot          = true
  deletion_protection          = false
  backup_retention_period      = var.backup_retention_days
  backup_window                = "03:00-04:00"
  maintenance_window           = "sun:04:00-sun:05:00"
  storage_encrypted            = var.storage_encrypted
  auto_minor_version_upgrade   = true
  apply_immediately            = true
  performance_insights_enabled = false

  tags = {
    Environment = var.environment
    Project     = "avl-traccar"
  }
}
