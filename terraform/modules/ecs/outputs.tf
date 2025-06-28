output "cluster_id" {
  description = "The ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_id" {
  description = "The ID of the ECS service"
  value       = aws_ecs_service.app.id
}

output "service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "The ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "target_group_name" {
  description = "The name of the target group"
  value       = aws_lb_target_group.app.name
}

output "alb_listener_arn" {
  description = "The ARN of the ALB listener"
  value       = aws_lb_listener.http.arn
}