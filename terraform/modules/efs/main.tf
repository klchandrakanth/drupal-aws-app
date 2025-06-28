# EFS File System
resource "aws_efs_file_system" "drupal_content" {
  creation_token = "${var.environment}-drupal-content"
  encrypted       = true

  tags = {
    Name = "${var.environment}-drupal-content"
  }
}

# EFS Access Point
resource "aws_efs_access_point" "drupal_content" {
  file_system_id = aws_efs_file_system.drupal_content.id

  root_directory {
    path = "/drupal-content"
    creation_info {
      owner_gid   = 48  # apache group
      owner_uid   = 48  # apache user
      permissions = "755"
    }
  }

  posix_user {
    gid = 48  # apache group
    uid = 48  # apache user
  }

  tags = {
    Name = "${var.environment}-drupal-content-access-point"
  }
}

# EFS Access Point for MariaDB
resource "aws_efs_access_point" "mariadb_data" {
  file_system_id = aws_efs_file_system.drupal_content.id

  root_directory {
    path = "/mariadb-data"
    creation_info {
      owner_gid   = 999  # mysql group
      owner_uid   = 999  # mysql user
      permissions = "755"
    }
  }

  posix_user {
    gid = 999  # mysql group
    uid = 999  # mysql user
  }

  tags = {
    Name = "${var.environment}-mariadb-data-access-point"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "drupal_content" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.drupal_content.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_groups
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${var.environment}-efs-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = var.ecs_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-efs-sg"
  }
}