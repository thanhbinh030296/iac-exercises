output "nat_public_ip" {
  value = aws_nat_gateway.private_nat.public_ip
}


output "ubuntu_image" {
  value = data.aws_ami.ubuntu_ami
}