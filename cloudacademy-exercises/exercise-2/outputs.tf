output "nat_public_ip" {
  value = aws_nat_gateway.private_nat.public_ip
}