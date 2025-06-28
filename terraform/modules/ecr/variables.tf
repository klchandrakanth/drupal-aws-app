variable "environment" {
  description = "Environment name"
  type        = string
}

variable "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  type        = string
}