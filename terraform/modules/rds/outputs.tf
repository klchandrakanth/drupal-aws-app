output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_identifier" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_name" {
  description = "The name of the database"
  value       = aws_db_instance.main.db_name
}