output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "service_name" {
  value = aws_ecs_service.traccar.name
}

output "task_family" {
  value = aws_ecs_task_definition.traccar.family
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.traccar.name
}
