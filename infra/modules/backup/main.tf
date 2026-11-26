resource "aws_s3_bucket" "backups" {
  count  = var.enabled ? 1 : 0
  bucket = "${var.prefix}-traccar-backups"

  tags = {
    Environment = var.environment
    Purpose     = "backups"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  count  = var.enabled ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count                   = var.enabled ? 1 : 0
  bucket                  = aws_s3_bucket.backups[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
