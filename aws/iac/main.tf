# Data sources for Availability Zones and Latest Amazon Linux 2023 AMI
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# -----------------------------------------------------------------------------
# VPC & Networking Infrastructure
# -----------------------------------------------------------------------------
resource "aws_vpc" "todo_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "todo-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.todo_vpc.id

  tags = {
    Name = "todo-igw"
  }
}

# Public Subnets (EC2 Application Host)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.todo_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "todo-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.todo_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "todo-public-subnet-2"
  }
}

# Private Subnets (RDS Isolation)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.todo_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "todo-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.todo_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "todo-private-subnet-2"
  }
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.todo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "todo-public-rt"
  }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# EC2 Application & Monitoring Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "todo-ec2-security-group"
  description = "Security group for Todo Application EC2 host"
  vpc_id      = aws_vpc.todo_vpc.id

  # SSH Access (restricted)
  ingress {
    description = "SSH from allowed admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }

  # Web Traffic
  ingress {
    description = "HTTP web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS web traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Spring Boot Backend API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "React Frontend SPA"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Monitoring Endpoints
  ingress {
    description = "Prometheus Metrics UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana Dashboards"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "todo-ec2-sg"
  }
}

# RDS Security Group (Strictly restricted to EC2 Security Group)
resource "aws_security_group" "rds_sg" {
  name        = "todo-rds-security-group"
  description = "Allows MySQL traffic exclusively from EC2 security group"
  vpc_id      = aws_vpc.todo_vpc.id

  ingress {
    description     = "MySQL access from EC2 security group only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    description = "No outbound connection required for private RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "todo-rds-sg"
  }
}

# -----------------------------------------------------------------------------
# IAM Role & Instance Profile for EC2
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "todo-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "todo-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# -----------------------------------------------------------------------------
# AWS RDS MySQL Database Instance
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "todo-rds-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "todo-rds-subnet-group"
  }
}

resource "aws_db_instance" "mysql_rds" {
  identifier             = "todo-mysql-rds"
  allocated_storage      = 20
  max_allocated_storage  = 50
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  backup_retention_period = 7

  tags = {
    Name = "todo-mysql-rds-instance"
  }
}

# -----------------------------------------------------------------------------
# AWS EC2 Application Instance
# -----------------------------------------------------------------------------
resource "aws_instance" "app_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = var.ec2_instance_type
  subnet_id            = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              echo "Starting EC2 User Data script..."
              dnf update -y
              dnf install -y docker git
              systemctl enable --now docker
              usermod -aG docker ec2-user
              
              # Install Docker Compose Plugin
              DOCKER_CONFIG=/usr/libexec/docker/cli-plugins
              mkdir -p $DOCKER_CONFIG
              curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/docker-compose
              chmod +x $DOCKER_CONFIG/docker-compose
              
              # Create application directory
              mkdir -p /opt/todo-app
              chown ec2-user:ec2-user /opt/todo-app
              echo "EC2 Setup Completed Successfully!"
              EOF

  tags = {
    Name = "todo-app-ec2-server"
  }
}
