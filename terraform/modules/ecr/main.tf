# ECR Repository
resource "aws_ecr_repository" "drupal" {
  name                 = "${var.environment}-drupal"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.environment}-drupal-repository"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "drupal" {
  repository = aws_ecr_repository.drupal.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "untagged"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository Policy
resource "aws_ecr_repository_policy" "drupal" {
  repository = aws_ecr_repository.drupal.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodeBuild"
        Effect = "Allow"
        Principal = {
          AWS = var.codebuild_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}