output "dashboard_name" {
  value = aws_cloudwatch_dashboard.this.dashboard_name
}

output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.availability.alarm_name
}
