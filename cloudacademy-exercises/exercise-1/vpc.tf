resource "aws_vpc" "b0ttle_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "b0ttle vpc"
  }
}

locals {
  available_zones = ["a","b"]
  public_subnet_cidr = ["10.0.1.0/24","10.0.2.0/24"] 
}


resource "aws_subnet" "public_subnets" {
  count  = length(local.available_zones)
  vpc_id     = aws_vpc.b0ttle_vpc.id
  cidr_block = local.public_subnet_cidr[count.index]
  availability_zone = "${var.region}${local.available_zones[count.index]}"

  tags = {
    Name = "public-subnet-${count.index}"
  }
}


resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.b0ttle_vpc.id

  tags = {
    Name = "public internet gateway"
  }
}


resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.b0ttle_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

  tags = {
    Name = "public route table"
  }
}


resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnets[0].id
  route_table_id = aws_route_table.public_route_table.id
}   



