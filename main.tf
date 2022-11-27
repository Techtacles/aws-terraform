
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  profile = "terraform-user"
}

#Creating a vpc
resource "aws_vpc" "first_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      "Name" = "Production vpc"
    }
}

#Create internet gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.first_vpc.id

  tags = {
    Name = "Production internet gateway"
  }
}
#Create custom route table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.first_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }



  tags = {
    Name = "Production-route"
  }
}

variable "cidr_block" {
    description = "This is a variable for cidr block"
    default="0.0.0.0"
}

#Create subnet
resource "aws_subnet" "first_subnet" {
  vpc_id     = aws_vpc.first_vpc.id
  cidr_block = var.cidr_block
  availability_zone = "us-east-1a"

  tags = {
    Name = "Production subnet"
  }
}
#Associate route table to subnet
resource "aws_route_table_association" "route_association" {
  subnet_id      = aws_subnet.first_subnet.id
  route_table_id = aws_route_table.route_table.id
}
# Create a security group
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.first_vpc.id

# We allow connections from_port to_port. This allows us specify a range of ports we want to receive connections from.
  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # We do this because we want to create a public url people can access.
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # We do this because we want to create a public url people can access.
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_connections"
  }
}
# Create a network interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.first_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_tls.id]
  
}
# Create elastic ip
resource "aws_eip" "elastic_ip" {
  instance = aws_instance.ec2.id
  vpc      = true
  associate_with_private_ip = "10.0.1.50"
  depends_on =  [aws_internet_gateway.internet-gateway]
  
}
#Create ubuntu server and install apache
resource "aws_instance" "ec2" {
  ami           = "ami-0b0dcb5067f052a63" # us-west-2
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
    
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              EOF
}