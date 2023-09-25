# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "MainVPC"
  }
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true # Enable public IPs for instances in this subnet

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

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

# Create a NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "NATGateway"
  }
}

# Create an Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

# Create a route table for the public subnet
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

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a route table for private subnets
resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "PrivateRouteTable-${count.index + 1}"
  }
}

# Create a route in each private route table pointing to the NAT Gateway
resource "aws_route" "private" {
  count                = 2
  route_table_id       = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id       = aws_nat_gateway.nat.id
}

# Associate private subnets with their respective private route tables
resource "aws_route_table_association" "private" {
  count        = 2
  subnet_id    = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, count.index)
}

# Create a security group for React-django app
resource "aws_security_group" "react_django" {
  name_prefix = "React-django"
  vpc_id      = aws_vpc.main.id

  # Inbound rule for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Inbound rule for HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule for all outbound traffic
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a private key and key pair for EC2 instances
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-key-pair"
  public_key = tls_private_key.private_key.public_key_openssh
}

# Create an EC2 instance in the public subnet
resource "aws_instance" "public_instance" {
  ami           = "ami-0f5ee92e2d63afc18" # Replace with your desired AMI ID for the public instance
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  associate_public_ip_address = true # Enable a public IP for this instance
  key_name               = aws_key_pair.generated_key.key_name # Associate with the key pair
  vpc_security_group_ids = [aws_security_group.react_django.id] # Attach the security group
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              service nginx start
              EOF

  # ... other instance configuration ...
}

# Create two EC2 instances in the private subnets
resource "aws_instance" "private_instance" {
  count         = 2
  ami           = "ami-0f5ee92e2d63afc18" # Replace with your desired AMI ID for the private instances
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.private[*].id, count.index)
  key_name      = aws_key_pair.generated_key.key_name # Associate with the key pair
  vpc_security_group_ids = [aws_security_group.react_django.id] # Attach the security group
  
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
  value = aws_subnet.private[*].id
}