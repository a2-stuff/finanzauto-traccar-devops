variable "aws_endpoint" {
  type        = string
  description = "Endpoint de Floci (AWS emulado)."
  default     = "http://localhost:4566"
}

variable "aws_region" {
  type        = string
  description = "Region logica de Floci."
  default     = "us-east-1"
}

provider "aws" {
  region     = var.aws_region
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  s3_use_path_style           = true

    endpoints {
      apigateway          = var.aws_endpoint
      cloudwatch          = var.aws_endpoint
      cloudwatchevents    = var.aws_endpoint
      cloudwatchlogs      = var.aws_endpoint
      dynamodb            = var.aws_endpoint
      ec2                 = var.aws_endpoint
      ecr                 = var.aws_endpoint
      ecs                 = var.aws_endpoint
      elasticloadbalancing = var.aws_endpoint
      iam                 = var.aws_endpoint
      kms                 = var.aws_endpoint
      logs                = var.aws_endpoint
      rds                 = var.aws_endpoint
      s3                  = var.aws_endpoint
      secretsmanager      = var.aws_endpoint
      sns                 = var.aws_endpoint
      ssm                 = var.aws_endpoint
      sts                 = var.aws_endpoint
    }
}
