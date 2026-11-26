output "bucket" {
  value       = var.enabled ? aws_s3_bucket.backups[0].bucket : ""
  description = "Nombre del bucket de respaldos, o cadena vacia."
}
