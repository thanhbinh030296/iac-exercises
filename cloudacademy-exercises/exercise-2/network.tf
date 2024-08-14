

resource "aws_vpc" "b0ttle_vpc" {
  cidr_block = "172.16.0.0/16"
  tags = {
    Name = "b0ttle-VPC"
  }
}

locals {
  available_zones     = ["a", "b"]
  private_subnet_cidr = ["172.16.1.0/24", "172.16.2.0/24"]
  public_subnet_cidr  = ["172.16.3.0/24", "172.16.4.0/24"]

}


resource "aws_subnet" "private_subnets" {
  count             = length(local.private_subnet_cidr)
  vpc_id            = aws_vpc.b0ttle_vpc.id
  cidr_block        = local.private_subnet_cidr[count.index]
  availability_zone = "${var.region}${local.available_zones[count.index]}"

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(local.public_subnet_cidr)
  vpc_id            = aws_vpc.b0ttle_vpc.id
  cidr_block        = local.public_subnet_cidr[count.index]
  availability_zone = "${var.region}${local.available_zones[count.index]}"
  tags = {
    Name = "public-subnet-${count.index}"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.b0ttle_vpc.id
  tags = {
    Name = "public-internet-gw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.b0ttle_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-route-table"
  }
}


resource "aws_route_table_association" "public_subnet_association" {
  count          = length(local.public_subnet_cidr)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}


resource "aws_eip" "nat_ip" {
  vpc = true
}

resource "aws_nat_gateway" "private_nat" {
  allocation_id = aws_eip.nat_ip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = {
    Name = "private_nat"
  }
}


resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.b0ttle_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private_nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}


resource "aws_route_table_association" "private_route_table_association" {
  count = length(local.private_subnet_cidr)
  subnet_id      = "${aws_subnet.private_subnets[count.index].id}"
  route_table_id = "${aws_route_table.private_route_table.id}"
}