provider "aws" {
  region = "ap-southeast-1"

}

locals {
  region              = "ap-southeast-1"
  available_zones     = ["a", "b", "c"]
  public_sunet_cidr   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidr = ["10.0.11.0/24", "10.0.22.0/24", "10.0.33.0/24"]
}
resource "aws_vpc" "b0ttle_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "b0ttle_vpc"
  }
}



# PUBLIC SUBNETS
resource "aws_subnet" "public_subnet" {
  count             = length(local.available_zones)
  vpc_id            = aws_vpc.b0ttle_vpc.id
  cidr_block        = local.public_sunet_cidr[count.index]
  availability_zone = "${local.region}${local.available_zones[count.index]}"
  tags = {
    Name = "public-subnet-${local.region}${local.available_zones[count.index]}"
  }
}



resource "aws_internet_gateway" "internet_gw_public" {
  vpc_id = aws_vpc.b0ttle_vpc.id
  tags = {
    Name = "internet-gateway for public subnets"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.b0ttle_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw_public.id
  }

  tags = {
    Name = "public_route_tables"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_association" {
  count          = length(local.available_zones)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# PRIVATE SUBNET

resource "aws_subnet" "private_subnet" {
  count      = length(local.available_zones)
  vpc_id     = aws_vpc.b0ttle_vpc.id
  cidr_block = local.private_subnet_cidr[count.index]
  availability_zone = "${local.region}${local.available_zones[count.index]}"
  tags = {
    Name = "private-subnet-${local.region}${local.available_zones[count.index]}"
  }
}





resource "aws_nat_gateway" "nat_gw" {
  #allocation_id = aws_eip.nat.id
  subnet_id         = aws_subnet.public_subnet[0].id
  connectivity_type = "private"
  tags = {
    Name = "nat_private_gw"
  }
}


resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.b0ttle_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private_route_table"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = length(local.private_subnet_cidr)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}



###

output "az-name" {
  value = tolist([
    for v in local.available_zones : "ap-southeast-1${v}"
  ])
}
output "aws-public-subnet" {
  value = [aws_subnet.public_subnet[*].tags["Name"]]
}
