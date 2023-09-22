# resource "aws_instance" "myec2" {
#   ami                    = "ami-08df646e18b182346"
#   instance_type          = "t2.micro"
#   availability_zone = "ap-south-1a"

#   tags = {
#     name = "testec2"
#   }
# }


# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "MainVPC"
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PublicSubnet"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 2}.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "PrivateSubnet-${count.index + 1}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

# # Create NAT Gateway
# resource "aws_nat_gateway" "nat" {
#   count = length(aws_subnet.private)

#   subnet_id = aws_subnet.private[count.index].id
#   allocation_id = aws_eip.nat[count.index].id
# }




# # Create a Route Table for Public Subnet
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.gw.id
#   }
# tags = {
#     Name = "PublicRouteTable"
#   }
# }

# # Associate Public Subnet with Public Route Table
# resource "aws_route_table_association" "public" {
#   subnet_id      = aws_subnet.public.id
#   route_table_id = aws_route_table.public.id
# }

# # Create a Route Table for Private Subnets
# resource "aws_route_table" "private" {
#   count  = length(aws_subnet.private)
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_nat_gateway.nat[count.index].id
#   }

#   tags = {
#     Name = "PrivateRouteTable-${count.index + 1}"
#   }
# }

# # Associate Private Subnets with Private Route Tables
# resource "aws_route_table_association" "private" {
#   count          = length(aws_subnet.private)
#   subnet_id      = aws_subnet.private[count.index].id
#   route_table_id = aws_route_table.private[count.index].id
#   nat_gateway_id        = aws_nat_gateway.nat.id
#   destination_cidr_block = "0.0.0.0/0" # Route all traffic
# }

# # Create a Security Group for React-django app
# resource "aws_security_group" "React-django" {
#   name_prefix = "React-django"
#   vpc_id      = aws_vpc.main.id

#   # Inbound rule
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/24"]
#   }
#  # Inbound rule
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# # Inbound rule
# ingress {
#     from_port   = 0
#     to_port     = 65535
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

# }



