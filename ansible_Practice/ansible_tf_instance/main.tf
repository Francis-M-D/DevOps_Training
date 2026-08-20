terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.58.0"
    }
  }

  #Terraform Remote Backend
  backend "s3" {
    bucket       = "my-tf-st-bkt"
    key          = "ansible-practice/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}

#Provider
provider "aws" {
  region = "ap-south-1"
}


#VPC
resource "aws_vpc" "ansible_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ansible_vpc"
  }
}

#Subnet
resource "aws_subnet" "ansible_subnet" {
  vpc_id            = aws_vpc.ansible_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Ansible_Subnet"
  }
}


#IGW
resource "aws_internet_gateway" "ansible_igw" {
  vpc_id = aws_vpc.ansible_vpc.id

  tags = {
    Name = "Ansible_IGW"
  }
}


#Route Table
resource "aws_route_table" "ansible_rt" {
  vpc_id = aws_vpc.ansible_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ansible_igw.id
  }

  tags = {
    Name = "Ansible RT"
  }
}

#Route Table Association
resource "aws_route_table_association" "ansible_rta" {
  subnet_id      = aws_subnet.ansible_subnet.id
  route_table_id = aws_route_table.ansible_rt.id
}


resource "aws_security_group" "ansible_sg" {
  name        = "allow_tls"
  vpc_id      = aws_vpc.ansible_vpc.id
  description = "Allow TLS inbound traffic and all outbound traffic"

  ingress {

    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {

    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {

    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "ansible_sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ansible_master" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = aws_subnet.ansible_subnet.id
  vpc_security_group_ids      = [aws_security_group.ansible_sg.id]
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = "LinuxKey"

  tags = {
    Name = "ansible_master"
  }
}

resource "aws_instance" "ansible_worker" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = aws_subnet.ansible_subnet.id
  vpc_security_group_ids      = [aws_security_group.ansible_sg.id]
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = "LinuxKey"

  tags = {
    Name = "ansible_worker"
  }
}


output "ansible_master_public_ip" {
  value = aws_instance.ansible_master.public_ip
}

output "ansible_worker_public_ip" {
  value = aws_instance.ansible_worker.public_ip
}
