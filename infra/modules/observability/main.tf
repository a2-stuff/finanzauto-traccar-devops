resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "${var.prefix}-traccar-errors"
  log_group_name = var.log_group_name
  pattern        = "ERROR"

  metric_transformation {
    name          = "TraccarErrors"
    namespace     = "AVL/Traccar"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.prefix}-traccar"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Disponibilidad"
          region = "us-east-1"
          stat   = "Average"
          period = 60
          metrics = [
            ["AVL/Traccar", "Availability", "Environment", var.environment]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Errores"
          region = "us-east-1"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AVL/Traccar", "TraccarErrors"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Recursos (CPU)"
          region = "us-east-1"
          stat   = "Average"
          period = 60
          metrics = [
            ["AVL/Traccar", "CpuPercent", "Environment", var.environment]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "availability" {
  alarm_name          = "${var.prefix}-traccar-availability"
  alarm_description   = "Traccar no responde en ${var.environment}."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Availability"
  namespace           = "AVL/Traccar"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "breaching"
  dimensions = {
    Environment = var.environment
  }
}
