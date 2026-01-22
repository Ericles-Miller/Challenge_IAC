# ==================================================
# OUTPUTS DO MÓDULO VPC
# ==================================================

# ID da VPC
output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

# CIDR block da VPC
output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = module.vpc.vpc_cidr_block
}

# IDs das subnets públicas
output "public_subnets" {
  description = "Lista de IDs das subnets públicas"
  value       = module.vpc.public_subnets
}

# IDs das subnets privadas
output "private_subnets" {
  description = "Lista de IDs das subnets privadas"
  value       = module.vpc.private_subnets
}

# ID do Internet Gateway
output "igw_id" {
  description = "ID do Internet Gateway"
  value       = module.vpc.igw_id
}

# IDs dos NAT Gateways
output "nat_gateway_ids" {
  description = "Lista de IDs dos NAT Gateways"
  value       = module.vpc.natgw_ids
}
