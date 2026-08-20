#STEP1: DEFINE AWS VERSION
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

#STEP2: DEFINE THE REGION
provider "aws" {
  region = "ap-south-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_instance" "My_Terraform_EC2" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"

    tags = {
        Name = "learn-terraform"
    }
}
