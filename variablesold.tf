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
  default = "t2.micro"
}

variable "admin_user" {
  type    = string
  default = "admin"
}

variable "admin_password" {
  type    = string
  default = "admin"
}
