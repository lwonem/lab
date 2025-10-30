##############################
# 🔧 Provider AWS
##############################
provider "aws" {
  region = var.aws_region
}

##############################
# 🧩 Variables
##############################
variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3"
}

variable "instance_name" {
  description = "Nom de l'instance EC2"
  type        = string
  default     = "sandbox-debian"
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "ID AMI Debian (facultatif)"
  type        = string
  default     = ""
}

variable "admin_user" {
  description = "Nom d'utilisateur administrateur"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Mot de passe administrateur"
  type        = string
  default     = "admin"
}

##############################
# 🌐 VPC et sous-réseau (optionnel si tu as déjà ton VPC)
##############################
# Si tu veux te connecter à ton VPC existant, remplace par le bon subnet_id.
# Exemple : subnet-0abcd12345
data "aws_subnet" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

##############################
# 🔒 Security Group (SSH)
##############################
resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Autorise SSH (port 22)"
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
# 🖥️ Instance EC2 Debian
##############################
# Utilise AMI Debian officielle (si ami_id non défini)
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Debian

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

resource "aws_instance" "debian_ec2" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.debian.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  # Script d'initialisation
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
# 📤 Outputs Terraform
##############################
output "ec2_public_ip" {
  description = "Adresse IP publique de l'instance EC2"
  value       = aws_instance.debian_ec2.public_ip
}

output "ec2_private_ip" {
  description = "Adresse IP privée de l'instance EC2"
  value       = aws_instance.debian_ec2.private_ip
}

output "ec2_name" {
  description = "Nom de l'instance EC2"
  value       = aws_instance.debian_ec2.tags["Name"]
}
