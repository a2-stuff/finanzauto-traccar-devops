resource "aws_kms_key" "backups" {
  count                   = var.enabled ? 1 : 0
  description             = "CMK para respaldos de ${var.environment}."
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowKeyUseInFloci"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::000000000000:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Purpose     = "backups"
  }
}

resource "aws_s3_bucket" "backups" {
  count  = var.enabled ? 1 : 0
  bucket = "${var.prefix}-traccar-backups"

  tags = {
    Environment = var.environment
    Purpose     = "backups"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  count  = var.enabled ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.backups[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
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

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count  = var.enabled ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  rule {
    id     = "expire-old-dumps"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
