output "bastion_public_ip" {
  value = module.ec2.bastion_public_ip
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "db_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "app_private_ips" {
  value = module.ec2.app_private_ips
}

output "vpc_id" {
  value = module.vpc.vpc_id
}