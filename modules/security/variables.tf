variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "my_ip" {
  description = "Your public IP in CIDR form, for SSH access to bastion"
  type        = string
}