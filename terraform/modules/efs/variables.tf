variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for mount targets"
  type        = list(string)
}

variable "security_groups" {
  description = "List of security group IDs for mount targets"
  type        = list(string)
}

variable "ecs_security_groups" {
  description = "List of ECS security group IDs that need access to EFS"
  type        = list(string)
}