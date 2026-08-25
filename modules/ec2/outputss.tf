output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "app_instance_ids" {
  value = aws_instance.app[*].id
}

output "app_private_ips" {
  value = aws_instance.app[*].private_ip
}