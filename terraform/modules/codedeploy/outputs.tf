output "application_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.drupal.name
}

output "deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.drupal.deployment_group_name
}

output "codedeploy_role_arn" {
  description = "ARN of the CodeDeploy IAM role"
  value       = aws_iam_role.codedeploy_role.arn
}