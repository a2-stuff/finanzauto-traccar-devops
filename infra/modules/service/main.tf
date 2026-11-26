resource "aws_cloudwatch_log_group" "traccar" {
  name              = "/avl/${var.environment}/traccar"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    Project     = "avl-traccar"
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "traccar" {
  family                   = "${var.prefix}-traccar"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = var.cpu
  memory                   = var.memory

  container_definitions = jsonencode([
    {
      name      = "traccar"
      image     = var.image
      essential = true
      cpu       = var.cpu
      memory    = var.memory
      portMappings = [
        {
          containerPort = 8082
          hostPort      = var.host_web_port
          protocol      = "tcp"
        },
        {
          containerPort = 5055
          hostPort      = var.host_osmand_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "CONFIG_USE_ENVIRONMENT_VARIABLES", value = "true" },
        { name = "DATABASE_DRIVER", value = "org.postgresql.Driver" },
        { name = "DATABASE_URL", value = "jdbc:postgresql://${var.db_host}:${var.db_port}/${var.db_name}" },
        { name = "DATABASE_USER", value = var.db_username },
        { name = "DATABASE_PASSWORD_SECRET_ARN", value = var.db_secret_arn },
        { name = "AWS_ENDPOINT_URL", value = var.aws_endpoint_for_tasks },
        { name = "AWS_DEFAULT_REGION", value = "us-east-1" },
        { name = "AWS_ACCESS_KEY_ID", value = "test" },
        { name = "AWS_SECRET_ACCESS_KEY", value = "test" }
      ]
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = var.db_secret_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.traccar.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-endpoint"      = var.aws_endpoint_for_tasks
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_service" "traccar" {
  name            = "${var.prefix}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.traccar.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = var.environment == "prod" ? 100 : 0
  deployment_maximum_percent         = 200

  tags = {
    Environment = var.environment
  }
}
