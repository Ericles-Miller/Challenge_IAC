# ==================================================
# OUTPUTS DO PROJETO
# ==================================================

# VPC
output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = module.vpc.vpc_cidr
}

# Subnets
output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnets
}

# EC2
output "ec2_instance_id" {
  description = "ID da instância EC2"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "IP público da instância EC2"
  value       = module.ec2.public_ip
}

output "ec2_private_ip" {
  description = "IP privado da instância EC2"
  value       = module.ec2.private_ip
}

output "ec2_public_dns" {
  description = "DNS público da instância EC2"
  value       = module.ec2.public_dns
}

# Instruções de acesso
output "ssh_connection" {
  description = "Comando para conectar via SSH"
  value       = "ssh -i ~/.ssh/challenge-iac-key ubuntu@${module.ec2.public_ip}"
}
# ==================================================
# LOAD BALANCER
# ==================================================
output "lb_dns_name" {
  description = "DNS do Load Balancer (URL para acessar a aplicação)"
  value       = module.loadbalancer.lb_dns_name
}

output "lb_url" {
  description = "URL completa do Load Balancer"
  value       = "http://${module.loadbalancer.lb_dns_name}"
}

output "lb_arn" {
  description = "ARN do Load Balancer"
  value       = module.loadbalancer.lb_arn
}