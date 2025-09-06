provider "aws" {
  region = "us-east-2" # Change to your preferred region
}

# ----------------------------
# VPC Creation
# ----------------------------
resource "aws_vpc" "aurora_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "AuroraVPC"
  }
}

# ----------------------------
# Subnets
# ----------------------------
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.aurora_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"

  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.aurora_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2b"

  tags = {
    Name = "Public Subnet 2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.aurora_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-2a"

  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.aurora_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-2b"

  tags = {
    Name = "Private Subnet 2"
  }
}

# ----------------------------
# Internet Gateway (For Public Subnets)
# ----------------------------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.aurora_vpc.id

  tags = {
    Name = "AuroraIGW"
  }
}

# ----------------------------
# Route Tables
# ----------------------------
## Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.aurora_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

## Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_subnet_1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ----------------------------
# NAT Gateway (For Private Subnets)
# ----------------------------
resource "aws_eip" "nat_eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "AuroraNATGateway"
  }
}

# ----------------------------
# Private Route Table (For Private Subnets)
# ----------------------------
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.aurora_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

## Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_subnet_1_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_assoc" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# ----------------------------
# (Optional) VPC Endpoint for DynamoDB
# ----------------------------
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.aurora_vpc.id
  service_name = "com.amazonaws.us-east-2.dynamodb"
  route_table_ids = [aws_route_table.private_rt.id]

  tags = {
    Name = "DynamoDB VPC Endpoint"
  }
}

# ----------------------------
# Security Group for Aurora
# ----------------------------
resource "aws_security_group" "aurora_sg" {
  vpc_id = aws_vpc.aurora_vpc.id
  name   = "aurora-sg"

  ingress {
    description = "MySQL/Aurora Access"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Aurora Security Group"
  }
}

# ----------------------------
# Aurora MySQL Subnet Group
# ----------------------------
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "aurora-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "Aurora DB Subnet Group"
  }
}

# ----------------------------
# Aurora MySQL Cluster
# ----------------------------
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "web-alerts"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.04.0"
  database_name          = "logs"
  master_username        = "admin"
  master_password        = "securepassword123"
  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  vpc_security_group_ids  = [aws_security_group.aurora_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.aurora_subnet_group.name
  storage_encrypted       = false
  skip_final_snapshot     = true

  serverlessv2_scaling_configuration {
    min_capacity = 2
    max_capacity = 4
  }
}

# ----------------------------
# Aurora MySQL Cluster Instances
# ----------------------------
resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = "aurora-instance-0"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = "db.serverless"
  engine            = aws_rds_cluster.aurora_cluster.engine
  engine_version    = aws_rds_cluster.aurora_cluster.engine_version
  publicly_accessible = true
}

# ----------------------------
# Outputs
# ----------------------------
output "aurora_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}

output "reader_endpoint" {
  value = aws_rds_cluster.aurora_cluster.reader_endpoint
}
