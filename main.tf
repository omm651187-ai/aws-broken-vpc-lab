provider "aws" {
  region = "eu-north-1"
}

# Dynamically fetch the latest Amazon Linux 2023 AMI for eu-north-1 (or any region)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 1. Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "Broken-Lab-VPC" }
}

# 2. Create Internet Gateway (Intentionally missing from public route table - Bug #1)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "Lab-IGW" }
}

# 3. Public Subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a" # Stockholm AZ
  tags = { Name = "Public-Subnet" }
}

# Public Route Table (MISSING 0.0.0.0/0 route to IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "Broken-Public-RT" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Fix #1: Add the internet gateway route to the public route table
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# 4. Security Group (Blocking SSH - Bug #2)
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"] # (Allows SSH from anywhere for testing)
}

  # BUG: Port 22 (SSH) is missing!
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. EC2 Instance using the dynamic AMI data source
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro" # t3 instances are great for eu-north-1
  key_name = "demokey"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  tags = { Name = "Broken-Web-Instance" }
}