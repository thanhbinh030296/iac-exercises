provider "aws" {

}


data "aws_ami" "ubuntu_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu*22.04*amd64*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners      = ["amazon"]
}


resource "aws_security_group" "allow_allport" {
  name        = "allow_all"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.b0ttle_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all for testing"
  }
}


resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "myKey"       # Create "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { # Create "myKey.pem" to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./myKey.pem && chmod 400 myKey.pem"
  }
}


resource "aws_instance" "nginx" {
  #ami           = "ami-0497a974f8d5dcef8"
  ami = "${data.aws_ami.ubuntu_ami.id}"
  instance_type = "t3.micro"

  subnet_id       = aws_subnet.public_subnets[0].id
  security_groups = [aws_security_group.allow_allport.id]

  key_name = aws_key_pair.kp.key_name
  associate_public_ip_address = true
  user_data = <<EOF
  #!/bin/bash
  sudo apt update
  sudo apt install nginx
  EOF

  tags = {
    Name = "HelloWorld"
  }
}







output "ubuntu_ami_name" {
  value = data.aws_ami.ubuntu_ami.image_location
}
output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu_ami.id
}
