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
