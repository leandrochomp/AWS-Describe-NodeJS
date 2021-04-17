provider "aws" {
    region = "ap-southeast-2"
}

#get latest version of amazon_linux_2
data "aws_ami" "latest_amazon_linux_2" {
  most_recent = true
  filter {
    name   = "name"
    values = ["*amzn2-ami-hvm*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = [ "x86_64" ]
  }
  owners = ["amazon"]
}

#create a VPC
resource "aws_vpc" "custom-vpc" {
  cidr_block       = "10.100.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "CustomVPC"
  }
}

#create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.custom-vpc.id
}

#create Route Table
resource "aws_route_table" "custom-route-table" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Custom Route Table"
  }
}

#create subnet on ap-southeast-2a
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.custom-vpc.id
  cidr_block = "10.100.1.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "custom-subnet"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.custom-route-table.id
}

#Allow web ports traffic: 22, 80, 3000
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.custom-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodeJS"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id = aws_subnet.subnet-1.id
  private_ips = [ "10.100.1.50" ]
  security_groups = [aws_security_group.allow_web.id]
}

#Elastic
resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.100.1.50"
  depends_on = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

resource "aws_instance" "web-server-dnx" {
  ami           = data.aws_ami.latest_amazon_linux_2.id
  instance_type = "t2.micro"
  availability_zone = "ap-southeast-2a"
  key_name = "DNX_KP_2021"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
}

user_data = <<-EOF
              #!/bin/bash -xe
              # System Updates
              yum -y update
              yum -y upgrade
              sudo yum install -y gcc-c++ make
              # get node into yum
              curl -sL https://rpm.nodesource.com/setup_15.x | sudo -E bash -
              # install node:
              sudo yum install -y nodejs
              sudo pm i cross-env -g
              # install aws cli
              sudo yum install -y aws-cli
              EOF

  tags = {
    "Name" = "EC2 - Amazon Linux 2"
  }
}