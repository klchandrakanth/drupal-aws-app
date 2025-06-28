output "docker_build_project_name" {
  description = "Name of the Docker build CodeBuild project"
  value       = aws_codebuild_project.docker_build.name
}

output "content_deploy_project_name" {
  description = "Name of the content deployment CodeBuild project"
  value       = aws_codebuild_project.content_deploy.name
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild_role.arn
}