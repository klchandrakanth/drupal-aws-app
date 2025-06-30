terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "drupal-aws-app-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "drupal-aws-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  azs         = var.availability_zones
}

# EFS for Content Storage
module "efs" {
  source = "./modules/efs"

  environment        = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  security_groups   = [module.efs.security_group_id]
  ecs_security_groups = [module.vpc.app_security_group_id]
}

# ECR Repository
module "ecr" {
  source = "./modules/ecr"

  environment        = var.environment
  codebuild_role_arn = module.codebuild.codebuild_role_arn
}

# CodeBuild for CI/CD
module "codebuild" {
  source = "./modules/codebuild"

  environment        = var.environment
  github_repository_url = var.github_repository_url
  ecr_repository_uri    = module.ecr.repository_url
  efs_file_system_id    = module.efs.file_system_id
  efs_access_point_id   = module.efs.access_point_id
}

# ECS Cluster and Services
module "ecs" {
  source = "./modules/ecs"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id

  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  app_security_groups = [module.vpc.app_security_group_id, module.efs.security_group_id]
  alb_security_groups = [module.vpc.alb_security_group_id]

  db_name         = var.db_name
  db_username     = var.db_username
  db_password     = var.db_password
  db_root_password = var.db_root_password

  app_image = module.ecr.repository_url
  app_port  = var.app_port

  domain_name = var.domain_name

  efs_file_system_id  = module.efs.file_system_id
  efs_access_point_id = module.efs.access_point_id
}

# CodeDeploy for ECS
module "codedeploy" {
  source = "./modules/codedeploy"

  environment        = var.environment
  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  alb_listener_arn   = module.ecs.alb_listener_arn
  target_group_name  = module.ecs.target_group_name
  target_group_blue_name = module.ecs.target_group_blue_name
  target_group_green_name = module.ecs.target_group_green_name
}

# CloudWatch Logs
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment = var.environment
  app_name    = "drupal"
}

# Outputs
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

output "app_url" {
  description = "The URL of the Drupal application"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "efs_file_system_id" {
  description = "The ID of the EFS file system"
  value       = module.efs.file_system_id
}

output "codebuild_docker_project" {
  description = "Name of the Docker build CodeBuild project"
  value       = module.codebuild.docker_build_project_name
}

output "codebuild_content_project" {
  description = "Name of the content deployment CodeBuild project"
  value       = module.codebuild.content_deploy_project_name
}

output "codedeploy_application" {
  description = "Name of the CodeDeploy application"
  value       = module.codedeploy.application_name
}