variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ec2_instance_type" {
  description = "AWS EC2 instance type (Free Tier eligible default)"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "AWS RDS database instance class (Free Tier eligible default)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "MySQL initial database name"
  type        = string
  default     = "todo_db"
}

variable "db_username" {
  description = "MySQL database master user name"
  type        = string
  default     = "todouser"
}

variable "db_password" {
  description = "MySQL database master user password"
  type        = string
  sensitive   = true
}

variable "admin_ssh_cidr" {
  description = "Restricted IPv4 CIDR range allowed for SSH access to EC2"
  type        = string
  default     = "0.0.0.0/0"
}
