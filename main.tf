provider "aws" {
  region = var.aws_region
}

##############################
# Variables
##############################
variable "aws_region" {
  type    = string
  default = "eu-west-3"
}

variable "instance_name" {
  type    = string
  default = "sandbox-debian"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"  # compatible Free Tier
}

variable "admin_user" {
  type    = string
  default = "admin"
}

variable "admin_password" {
  type    = string
  default = "admin"
}

##############################
# Subnet par défaut
##############################
data "aws_subnet" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

##############################
# Security Group pour SSH
##############################
resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Autorise SSH"
  vpc_id      = data.aws_subnet.default.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "${var.instance_name}-sg"
  }
}

##############################
# Dernière AMI Debian Free Tier
##############################
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Debian

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"] # Debian 12 latest
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##############################
# EC2 instance
##############################
resource "aws_instance" "debian_ec2" {
  ami                         = data.aws_ami.debian.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y sudo openssh-server
    useradd -m -s /bin/bash ${var.admin_user}
    echo "${var.admin_user}:${var.admin_password}" | chpasswd
    usermod -aG sudo ${var.admin_user}
    systemctl enable ssh
    systemctl start ssh
  EOF

  tags = {
    Name = var.instance_name
  }
}

##############################
# Outputs
##############################
output "ec2_public_ip" {
  description = "IP publique EC2"
  value       = aws_instance.debian_ec2.public_ip
}

output "ec2_private_ip" {
  description = "IP privée EC2"
  value       = aws_instance.debian_ec2.private_ip
}

output "ec2_name" {
  description = "Nom de l'instance EC2"
  value       = aws_instance.debian_ec2.tags["Name"]
}
