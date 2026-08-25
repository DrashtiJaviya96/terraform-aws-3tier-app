locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------- Latest Amazon Linux 2023 AMI ----------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------- Bastion Host (public subnet, AZ-a) ----------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${local.name_prefix}-bastion"
  }
}

# ---------- App Servers (private subnets, one per AZ) ----------
resource "aws_instance" "app" {
  count                  = length(var.private_subnet_ids)
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [var.ec2_app_sg_id]
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "<h1>App server $(hostname -f) - ${var.environment}</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "${local.name_prefix}-app-${count.index + 1}"
  }
}