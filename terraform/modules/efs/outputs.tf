output "file_system_id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.drupal_content.id
}

output "access_point_id" {
  description = "The ID of the EFS access point"
  value       = aws_efs_access_point.drupal_content.id
}

output "security_group_id" {
  description = "The ID of the EFS security group"
  value       = aws_security_group.efs.id
}