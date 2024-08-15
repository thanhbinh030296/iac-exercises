provider "aws" {

}


resource "aws_security_group" "loadbalancer_sg" {
  name        = "loadbalancer_sg"
  description = "loadbalancer SG"
  vpc_id      = aws_vpc.b0ttle_vpc.id

  ingress {
    description = "allow from internet to ALB"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "load_balancer_sg"
  }
}



resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow traffic from alb to ec2"
  vpc_id      = aws_vpc.b0ttle_vpc.id


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow traffic to internet"
  }

  tags = {
    Name = "ec2_sg"
  }
}


resource "aws_security_group_rule" "access_from_ALB_to_EC2" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_sg.id
  security_group_id        = aws_security_group.loadbalancer_sg.id
  description              = "egress to access from alb to ec2"
}


resource "aws_security_group_rule" "ingress_acceSS_from_ALB_to_EC2" {
  security_group_id        = aws_security_group.ec2_sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.loadbalancer_sg.id
  description              = "allow to be able to access from the alb to ec2"
}





# Create a new load balancer
resource "aws_lb" "alb_nginx" {
  name               = "alb-nginx"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer_sg.id]
  subnets            = [for s in aws_subnet.public_subnets : s.id]
  #enable_deletion_protection = true

  tags = {
    Environment = "dev"
    Name        = "alb-nginx"
  }
}




resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "b0ttle_key" {
  key_name   = "b0ttle-key"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "private_key_of_project" {
  content  = tls_private_key.private_key.private_key_pem
  filename = "${aws_key_pair.b0ttle_key.key_name}.pem"
}


data "aws_ami" "ubuntu_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images*22.04*amd64*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  owners = ["099720109477"] # Canonical
}



resource "aws_launch_template" "launch_template_nginx" {
  name                   = "foo"
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 8
    }
  }

  #disable_api_termination = true

  #ebs_optimized = true

  image_id = data.aws_ami.ubuntu_ami.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t3.micro"

  key_name = aws_key_pair.b0ttle_key.key_name
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }
  user_data = filebase64("ec2.userdata")


  #placement {  
  #  availability_zone = [for v in aws_subnet.private_subnets : v.availability_zone ]
  #}

  vpc_security_group_ids = ["${aws_security_group.ec2_sg.id}"]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }

}


resource "aws_placement_group" "placement_group_nginx" {
  name     = "test"
  strategy = "cluster"
}

resource "aws_autoscaling_group" "asg_nginx" {
  name                      = "asg_nginx"
  max_size                  = 2
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  #placement_group           = aws_placement_group.placement_group_nginx.id
  launch_template {
    id      = aws_launch_template.launch_template_nginx.id
    version = "$Latest"
  }
  vpc_zone_identifier = [for subnet_name in aws_subnet.private_subnets : subnet_name.id]

  tag {
    key                 = "foo"
    value               = "bar"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }
  tag {
    key                 = "lorem"
    value               = "ipsum"
    propagate_at_launch = false
  }
}

resource "aws_lb_target_group" "nginx_target_group" {
  name     = "nginx-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.b0ttle_vpc.id
  
}


# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "asg_attachment_targetgroup" {
  autoscaling_group_name = aws_autoscaling_group.asg_nginx.id
  lb_target_group_arn = aws_lb_target_group.nginx_target_group.arn
}


resource "aws_lb_listener" "nginx_80" {
  load_balancer_arn = aws_lb.alb_nginx.arn
  port              = "80"
  protocol          = "HTTP"
  
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
}