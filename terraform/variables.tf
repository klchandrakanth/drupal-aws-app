variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "drupal"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "drupal"
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
  default     = "drupal-aws-app:latest"
}

variable "app_port" {
  description = "Port the application runs on"
  type        = number
  default     = 80
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}

variable "app_count" {
  description = "Number of application instances"
  type        = number
  default     = 1
}

variable "app_cpu" {
  description = "CPU units for the application"
  type        = number
  default     = 1024
}

variable "app_memory" {
  description = "Memory for the application in MB"
  type        = number
  default     = 2048
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "github_repository_url" {
  description = "GitHub repository URL for source code"
  type        = string
}