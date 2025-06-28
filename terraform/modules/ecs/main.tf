# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-drupal-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.environment}-drupal-cluster"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.environment}-drupal-app"
  retention_in_days = 7

  tags = {
    Name = "${var.environment}-drupal-app-logs"
  }
}

resource "aws_cloudwatch_log_group" "mariadb" {
  name              = "/ecs/${var.environment}-drupal-mariadb"
  retention_in_days = 7

  tags = {
    Name = "${var.environment}-drupal-mariadb-logs"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.environment}-drupal-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "drupal-content"
    efs_volume_configuration {
      file_system_id          = var.efs_file_system_id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "mariadb-data"
    efs_volume_configuration {
      file_system_id          = var.efs_file_system_id
      root_directory          = "/mariadb"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = var.efs_mariadb_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "drupal-mariadb"
      image = "mariadb:10.6"

      portMappings = [
        {
          containerPort = 3306
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "MYSQL_ROOT_PASSWORD"
          value = var.db_root_password
        },
        {
          name  = "MYSQL_DATABASE"
          value = var.db_name
        },
        {
          name  = "MYSQL_USER"
          value = var.db_username
        },
        {
          name  = "MYSQL_PASSWORD"
          value = var.db_password
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "mariadb-data"
          containerPath = "/var/lib/mysql"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.mariadb.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "mysqladmin ping -h localhost -u root -p${var.db_root_password} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name  = "drupal-app"
      image = var.app_image

      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = "localhost"
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "DB_PASS"
          value = var.db_password
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "drupal-content"
          containerPath = "/var/www/html/web/sites/default/files"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      dependsOn = [
        {
          containerName = "drupal-mariadb"
          condition     = "HEALTHY"
        }
      ]
    }
  ])

  tags = {
    Name = "${var.environment}-drupal-task-definition"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.environment}-drupal-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_groups
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.environment}-drupal-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "app" {
  name        = "${var.environment}-drupal-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.environment}-drupal-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.environment}-drupal-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = var.app_security_groups
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "drupal-app"
    container_port   = var.app_port
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${var.environment}-drupal-service"
  }
}

# IAM Role for ECS Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# EFS permissions for ECS execution role
resource "aws_iam_role_policy" "ecs_execution_efs_policy" {
  name = "${var.environment}-ecs-execution-efs-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# EFS permissions for ECS task role
resource "aws_iam_role_policy" "ecs_task_efs_policy" {
  name = "${var.environment}-ecs-task-efs-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = "*"
      }
    ]
  })
}

# Data source for current region
data "aws_region" "current" {}