output "ec2_public_ip" {
  description = "Public IP address of the application EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the application EC2 instance"
  value       = aws_instance.app_server.public_dns
}

output "rds_endpoint" {
  description = "Connection endpoint for the private RDS MySQL instance"
  value       = aws_db_instance.mysql_rds.endpoint
}

output "rds_address" {
  description = "Address host of the private RDS MySQL instance"
  value       = aws_db_instance.mysql_rds.address
}
