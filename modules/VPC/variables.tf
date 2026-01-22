# Nome da VPC
variable "vpc_name" {
  type        = string
  description = "Nome da VPC"
}

# Range de IPs da VPC (ex: 10.0.0.0/16)
variable "vpc_cidr" {
  type        = string
  description = "CIDR block da VPC"
}

# Zonas de disponibilidade
variable "availability_zones" {
  type        = list(string)
  description = "Lista de Availability Zones"
}

# Subnets privadas (sem acesso direto à internet)
variable "private_subnets" {
  type        = list(string)
  description = "CIDRs das subnets privadas"
}

# Subnets públicas (com acesso à internet)
variable "public_subnets" {
  type        = list(string)
  description = "CIDRs das subnets públicas"
}

# Habilitar NAT Gateway (permite subnets privadas acessarem internet)
variable "enable_nat_gateway" {
  type        = bool
  description = "Habilitar NAT Gateway"
  default     = true
}

# Habilitar VPN Gateway
variable "enable_vpn_gateway" {
  type        = bool
  description = "Habilitar VPN Gateway"
  default     = false
}

# Ambiente
variable "environment" {
  type        = string
  description = "Ambiente (dev, prod, staging)"
}

# Tags personalizadas
variable "tags" {
  type        = map(string)
  description = "Tags adicionais"
  default     = {}
}
