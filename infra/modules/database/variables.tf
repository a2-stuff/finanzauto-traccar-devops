variable "prefix" { type = string }
variable "environment" { type = string }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "master_password" {
  type      = string
  sensitive = true
}
variable "backup_retention_days" { type = number }
variable "storage_encrypted" { type = bool }
