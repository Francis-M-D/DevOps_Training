resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "my_vpc"
  }
}

resource "aws_subnet" "my_pub_sub" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "my_pub_sub"
  }
}

resource "aws_subnet" "my_pri_sub" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "my_pri_sub"
  }
}

resource "aws_internet_gateway" "my_int_gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_int_gw"
  }
}
