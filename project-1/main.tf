terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "us-east-2"

}

# 1. Create a VPC
resource "aws_vpc" "testVpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "test-vpc"
  }
}
# 2. Create an IGW
resource "aws_internet_gateway" "testIGW" {
  vpc_id = aws_vpc.testVpc.id

  tags = {
    Name = "test-igw"
  }
}
# 3. Create a Custom route table
resource "aws_route_table" "testRouteTable" {
  vpc_id = aws_vpc.testVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.testIGW.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.testIGW.id
  }

  tags = {
    "Name" = "test-route-table"
  }

}
# 4. Create a subnet

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.testVpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "subnet-1"
  }
}
# 5. Associate subnet with route table
resource "aws_route_table_association" "testRouteTabletoSubnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.testRouteTable.id
}
# 6. Create security group to allow port 22, 80, 443
resource "aws_security_group" "allowWebTraffic" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.testVpc.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "testNic" {
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allowWebTraffic.id]

}
# 8. Assign an elastic IP to network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.testNic.id
  associate_with_private_ip = "10.0.1.50"

  depends_on = [
    aws_internet_gateway.testIGW
  ]
}
# 9. Create EC2
resource "aws_instance" "web" {
  # ami               = "ami-0c02fb55956c7d316"
  ami               = "ami-064ff912f78e3e561"
  instance_type     = "t2.micro"
  availability_zone = aws_subnet.subnet1.availability_zone
  key_name          = "testing-nick"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.testNic.id
  }

  /*
      user_data = << -EOF
                  #!/bin/bash
                  Here you can run bash commands
                  EOF
    */

  tags = {
    Name = "test-instance"
  }
}

