resource "aws_eip" "my_eip" {
  domain = "vpc"

  tags = {
    Name = "my_eip"
  }
}

resource "aws_nat_gateway" "my_nat_gw" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.my_pub_sub.id

  depends_on = [
    aws_internet_gateway.my_int_gw
  ]

  tags = {
    Name = "my_nat_gw"
  }
}
