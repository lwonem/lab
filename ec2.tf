#########################
# Variables
#########################
variable "instance_name" {
  type    = string
  default = "sandbox-debian"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

# Optionnel : peux laisser vide et utiliser un data "aws_ami" pour trouver l'AMI Debian
variable "ami_id" {
  type    = string
  default = ""  # si vide, on prendra un fallback (cf. data source ci-dessous)
}

variable "admin_user" {
  type    = string
  default = "admin"
}

variable "admin_password" {
  type    = string
  default = "admin"
}

#########################
# AMI selection (fallback)
#########################
# NOTE: il est recommandé d'externaliser l'AMI ou d'utiliser un param SSM. Ici on essaye d'avoir un fallback si ami_id vide.
data "aws_ami" "debian" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true

  filter {
    name   = "name"
    values = ["debian-*bookworm*","debian-12*"]
  }

  owners = ["136693071363"] # ATTENTION: peut varier selon région; si le data échoue, fournis ami_id via variable
}

#########################
# Key pair: none (nous n'utilisons pas key_name)
# Nous injectons user/password via user_data (cloud-init)
#########################

#########################
# EC2 instance
#########################
resource "aws_instance" "sandbox_vm" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.debian[0].id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sandbox_sg.id]

  associate_public_ip_address = true

  # user_data: create user, set password, enable password auth (for Debian/Ubuntu)
  user_data = <<-EOF
              #cloud-config
              users:
                - name: ${var.admin_user}
                  gecos: "Admin User"
                  primary_group: admin
                  groups: sudo
                  lock_passwd: false
                  passwd: ${trimspace(chomp(base64encode("${var.admin_password}")))} # placeholder not used, see runcmd
              runcmd:
                - [ bash, -lc, "useradd -m -s /bin/bash ${var.admin_user} || true" ]
                - [ bash, -lc, "echo '${var.admin_user}:${var.admin_password}' | chpasswd" ]
                - [ bash, -lc, "usermod -aG sudo ${var.admin_user} || true" ]
                - [ bash, -lc, "sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true" ]
                - [ bash, -lc, "systemctl restart ssh || systemctl restart sshd || true" ]
              EOF

  tags = {
    Name = var.instance_name
  }

  # Wait for instance to be ready
  provisioner "remote-exec" {
    when    = "create"
    inline  = ["echo instance created"]
    # We don't use connection as we rely on password auth; not advisable to connect with remote-exec here
  }
}

#########################
# Outputs
#########################
output "ec2_public_ip" {
  value = aws_instance.sandbox_vm.public_ip
}

output "ec2_private_ip" {
  value = aws_instance.sandbox_vm.private_ip
}

output "ec2_name" {
  value = aws_instance.sandbox_vm.tags["Name"]
}
