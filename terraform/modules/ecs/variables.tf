variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "app_security_groups" {
  description = "List of security group IDs for the application"
  type        = list(string)
}

variable "alb_security_groups" {
  description = "List of security group IDs for the ALB"
  type        = list(string)
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_root_password" {
  description = "Database root password"
  type        = string
  sensitive   = true
}

variable "app_image" {
  description = "Docker image for the application"
  type        = string
}

variable "app_port" {
  description = "Port the application runs on"
  type        = number
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}

variable "efs_file_system_id" {
  description = "EFS file system ID for content storage"
  type        = string
}

variable "efs_access_point_id" {
  description = "EFS access point ID for content storage"
  type        = string
}