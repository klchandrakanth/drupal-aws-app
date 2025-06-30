# S3 Bucket for CodeBuild artifacts
resource "aws_s3_bucket" "codebuild_artifacts" {
  bucket = "${var.environment}-drupal-codebuild-artifacts-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.environment}-drupal-codebuild-artifacts"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for CodeBuild logs
resource "aws_s3_bucket" "codebuild_logs" {
  bucket = "${var.environment}-drupal-codebuild-logs-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.environment}-drupal-codebuild-logs"
  }
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.environment}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.environment}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      },
      {
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.codebuild_artifacts.arn,
          "${aws_s3_bucket.codebuild_artifacts.arn}/*"
        ]
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
      },
      {
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.codebuild_logs.arn,
          "${aws_s3_bucket.codebuild_logs.arn}/*"
        ]
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
      },
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
      },
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
      },
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeAccessPoints"
        ]
      }
    ]
  })
}

# CodeBuild Project for Docker Image
resource "aws_codebuild_project" "docker_build" {
  name          = "${var.environment}-drupal-docker-build"
  description   = "Build Drupal Docker image"
  build_timeout = "60"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "S3"
    location = aws_s3_bucket.codebuild_artifacts.bucket
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = var.ecr_repository_uri
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.environment}-drupal-docker-build"
      stream_name = "build-log"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuild_logs.id}/docker-build-logs"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repository_url
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "refs/heads/main"

  tags = {
    Name = "${var.environment}-drupal-docker-build"
  }
}

# CodeBuild Project for Content Deployment
resource "aws_codebuild_project" "content_deploy" {
  name          = "${var.environment}-drupal-content-deploy"
  description   = "Deploy Drupal content to EFS"
  build_timeout = "30"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "S3"
    location = aws_s3_bucket.codebuild_artifacts.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "EFS_FILE_SYSTEM_ID"
      value = var.efs_file_system_id
    }

    environment_variable {
      name  = "EFS_ACCESS_POINT_ID"
      value = var.efs_access_point_id
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.environment}-drupal-content-deploy"
      stream_name = "build-log"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuild_logs.id}/content-deploy-logs"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repository_url
    git_clone_depth = 1
    buildspec       = "buildspec-content.yml"
  }

  source_version = "refs/heads/main"

  tags = {
    Name = "${var.environment}-drupal-content-deploy"
  }
}