terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-north-1"
  profile = "userdemo-terraform"
}

# 1. Create the VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "broken-vpc" }
}

# 2. Create an Internet Gateway
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = { Name = "broken-igw" }
}

# 3. Create a Subnet
resource "aws_subnet" "lab_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "broken-subnet" }
}

# 4. Create a Custom Route Table and public route
resource "aws_route_table" "lab_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  tags   = { Name = "broken-route-table" }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.lab_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab_igw.id
}

resource "aws_route_table_association" "lab_assoc" {
  subnet_id      = aws_subnet.lab_subnet.id
  route_table_id = aws_route_table.lab_rt.id
}

# 5. Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 6. Deploy a Test EC2 Instance
resource "aws_instance" "lab_vm" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.lab_subnet.id
  tags          = { Name = "troubleshoot-vm" }
}