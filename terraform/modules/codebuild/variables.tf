variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_repository_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "ecr_repository_uri" {
  description = "ECR repository URI"
  type        = string
}

variable "efs_file_system_id" {
  description = "EFS file system ID"
  type        = string
}

variable "efs_access_point_id" {
  description = "EFS access point ID"
  type        = string
}