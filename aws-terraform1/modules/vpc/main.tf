####################################################
# Availability Zones
####################################################
data "aws_availability_zones" "available" {}

####################################################
# VPC
####################################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

####################################################
# Internet Gateway
####################################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

####################################################
# Public Subnet 1
####################################################
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "public-subnet-1"
  })
}

####################################################
# Public Subnet 2
####################################################
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "public-subnet-2"
  })
}

####################################################
# Private Subnet 1
####################################################
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[0]
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = merge(var.tags, {
    Name = "private-subnet-1"
  })
}

####################################################
# Private Subnet 2
####################################################
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[1]
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = merge(var.tags, {
    Name = "private-subnet-2"
  })
}

####################################################
# Elastic IP for NAT
####################################################
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "travelbooking-nat-eip"
  })
}

####################################################
# NAT Gateway
####################################################
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1.id
  depends_on    = [aws_internet_gateway.this]

  tags = merge(var.tags, {
    Name = "travelbooking-nat"
  })
}

####################################################
# Public Route Table
####################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, {
    Name = "public-rt"
  })
}

####################################################
# Private Route Table
####################################################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = merge(var.tags, {
    Name = "private-rt"
  })
}

####################################################
# Route Table Associations
####################################################
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}
