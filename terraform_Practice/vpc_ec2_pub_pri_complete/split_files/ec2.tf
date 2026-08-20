data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
    ]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "public_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.my_pub_sub.id
  associate_public_ip_address = true
  key_name                    = var.key_name

  vpc_security_group_ids = [
    aws_security_group.my_pub_sg.id
  ]

  tags = {
    Name = "Public-EC2"
  }
}

resource "aws_instance" "private_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.my_pri_sub.id
  key_name      = var.key_name

  vpc_security_group_ids = [
    aws_security_group.my_pri_sg.id
  ]

  tags = {
    Name = "Private-EC2"
  }
}
