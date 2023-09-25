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
  availability_zone = "ap-south-1a"

  tags = {
    Name = "PublicSubnet"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 2}.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = false

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

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "NATGateway"
  }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

# Create a Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a Route Table for Private Subnets
resource "aws_route_table" "private" {
  # count  = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "PrivateRouteTable"
  }
  }
resource "aws_route" "private" {
  # count              = length(aws_subnet.private)
  route_table_id     = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id     = aws_nat_gateway.nat.id
}

# Create an Association between Private Subnets and the Private Route Table
resource "aws_route_table_association" "private" {
  count        = length(aws_subnet.private)
  subnet_id    = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create a Security Group for React-django app
resource "aws_security_group" "React-django" {
  name_prefix = "React-django"
  vpc_id      = aws_vpc.main.id

  # Inbound rule
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 # Inbound rule
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# Inbound rule
ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# # Create an AWS key pair using the generated public key
# resource "aws_key_pair" "my_key_pair" {
#   key_name   = "my-key-pair"  # Replace with your desired key name
#   public_key = file("~/.ssh/my_key_rsa.pub")  # Path to your public SSH key
# }
#  resource "aws_key_pair" "example" {
#   key_name   = "my-key-pair"  # Replace with your desired key name
#   public_key = file("~/.ssh/id_rsa.pub")  # Replace with the path to your public key file
#  }
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits = "4096"
}
resource "aws_key_pair" "generated_key" {
  key_name   = "my-key-pair"
  public_key = tls_private_key.private_key.public_key_openssh
}

# Create an EC2 Instance in the Public Subnet
resource "aws_instance" "public_instance" {
  ami           = "ami-0f5ee92e2d63afc18" # Replace with your desired AMI ID for the public instance
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  associate_public_ip_address = true # Enable a public IP for this instance
  key_name               = aws_key_pair.generated_key.key_name # Associate with the key pair
  vpc_security_group_ids = [aws_security_group.React-django.id] # Attach the security group
  # ... other instance configuration ...

  # user_data = <<-EOF
  #   #!/bin/bash
  #   ssh-keygen
  #   chmod 600 ~/.ssh/id_rsa
  #   chmod 644 ~/.ssh/id_rsa.pub
  #   EOF
}



# Create Two EC2 Instances in the Private Subnets
resource "aws_instance" "private_instance" {
  count         = 2
  ami           = "ami-0f5ee92e2d63afc18" # Replace with your desired AMI ID for the private instances
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.private[*].id, count.index)
  key_name      = aws_key_pair.generated_key.key_name # Associate with the key pair
  vpc_security_group_ids = [aws_security_group.React-django.id] # Attach the security group
  # ... other instance configuration ...
  user_data = <<-EOF
    #!/bin/bash
    sudo apt install nginx -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    EOF
}



# Outputs for convenience
output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_ids" {
  value = aws_subnet.private.*.id
}
