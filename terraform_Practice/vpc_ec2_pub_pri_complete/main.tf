terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#provider
provider "aws" {
  region = "ap-south-1"
}

#VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my_vpc"
  }
}

#PUBLIC SUBNET
resource "aws_subnet" "my_pub_sub" {
  vpc_id                  = aws_vpc.my_vpc.id
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  cidr_block              = "10.0.1.0/24"

  tags = {
    Name = "my_pub_sub"
  }
}

#PRIVATE SUBNET
resource "aws_subnet" "my_pri_sub" {
  vpc_id            = aws_vpc.my_vpc.id
  availability_zone = "ap-south-1a"
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name = "my_pri_sub"
  }
}

#INTERNET GATEWAY
resource "aws_internet_gateway" "my_int_gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_int_gw"
  }
}

#PUBLIC ROUTE TABLE
resource "aws_route_table" "my_pub_rtb" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_pub_rtb"
  }
}

#PUBLIC ROUTE
resource "aws_route" "my_pub_rt" {
  route_table_id         = aws_route_table.my_pub_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_int_gw.id
}

#PUBLIC ROUTE TABLE SUBNET ASSOCIATION
resource "aws_route_table_association" "my_pub_rbt_asn" {
  subnet_id      = aws_subnet.my_pub_sub.id
  route_table_id = aws_route_table.my_pub_rtb.id
}

#Elastic IP
resource "aws_eip" "my_eip" {
  domain = "vpc"

  tags = {
    Name = "my_eip"
  }
}

#NAT GATEWAY
resource "aws_nat_gateway" "my_nat_gw" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.my_pub_sub.id

  depends_on = [aws_internet_gateway.my_int_gw]

  tags = {
    Name = "my_nat_gw"
  }
}

#PRIVATE ROUTE TABLE
resource "aws_route_table" "my_pri_rtb" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_pri_rtb"
  }
}

#PRIVATE ROUTE
resource "aws_route" "my_pri_rt" {
  route_table_id         = aws_route_table.my_pri_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gw.id
}

#PRIVATE ROUTE TABLE SUBNET ASSOCIATION
resource "aws_route_table_association" "my_pri_rbt_asn" {
  subnet_id      = aws_subnet.my_pri_sub.id
  route_table_id = aws_route_table.my_pri_rtb.id
}

#PUBLIC SECURITY GROUP
resource "aws_security_group" "my_pub_sg" {
  name        = "my_pub_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS Access (Highly recommended companion for HTTP)
  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH Access
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_pub_sg"
  }
}

#PRIVATE SECURITY GROUP
resource "aws_security_group" "my_pri_sg" {
  name        = "my_pri_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description     = "Allow HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.my_pub_sg.id]
  }

  # HTTPS Access (Highly recommended companion for HTTP)
  ingress {
    description     = "Allow HTTPS"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.my_pub_sg.id]
  }

  # SSH Access
  ingress {
    description     = "Allow SSH"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.my_pub_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_pri_sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

#AWS EC2 INSTANCE - PUBLIC
resource "aws_instance" "public_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.my_pub_sub.id
  vpc_security_group_ids      = [aws_security_group.my_pub_sg.id]
  associate_public_ip_address = true
  key_name                    = "LinuxKey"

  tags = {
    Name = "Public-EC2"
  }
}

#AWS EC2 INSTANCE - PRIVATE
resource "aws_instance" "private_ec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.my_pri_sub.id
  vpc_security_group_ids = [aws_security_group.my_pri_sg.id]
  key_name               = "LinuxKey"

  tags = {
    Name = "Private-EC2"
  }
}

#OUTPUT
output "public_instance_ip" {
  value = aws_instance.public_ec2.public_ip
}

output "public_instance_id" {
  value = aws_instance.public_ec2.id
}

output "private_instance_id" {
  value = aws_instance.private_ec2.id
}

output "public_dns" {
  value = aws_instance.public_ec2.public_dns
}

output "private_ip" {
  value = aws_instance.private_ec2.private_ip
}
