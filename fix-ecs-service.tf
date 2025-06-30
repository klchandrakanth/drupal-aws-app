# Temporary fix for ECS service
# This file should be applied and then deleted

# Temporarily switch ECS service to use ECS deployment controller
resource "aws_ecs_service" "app_fix" {
  name            = "production-drupal-service"
  cluster         = "production-drupal-cluster"
  task_definition = "production-drupal-app:3"  # Use the new task definition revision
  desired_count   = 1

  deployment_controller {
    type = "ECS"  # Temporarily use ECS instead of CODE_DEPLOY
  }

  network_configuration {
    security_groups  = ["sg-099367486860677b0", "sg-0f02163b529fdc4ee"]
    subnets          = ["subnet-06e7ad172d13c3265", "subnet-04ab60d8f376e1489", "subnet-0a1d036993d8ac1ce"]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:396503876336:targetgroup/production-drupal-tg-blue/26aeb456d3020f46"
    container_name   = "drupal-app"
    container_port   = 80
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}