variable "environment" {
  type        = string
  description = "Ambiente (dev, prod)"
  default     = "dev"
}

variable "aws_profile" {
  type        = string
  description = "AWS Profile a ser usado"
  default     = "ericles-dev"
}

variable "aws_region" {
  type        = string
  description = "Região AWS"
  default     = "us-east-1"
}

# ==================================================
# VARIÁVEIS PARA EC2
# ==================================================

variable "ec2_instance_type" {
  type        = string
  description = "Tipo da instância EC2"
  default     = "t3.small"
}

variable "ec2_ami_id" {
  type        = string
  description = "AMI ID para a instância EC2 (Amazon Linux 2023)"
}

variable "ec2_key_name" {
  type        = string
  description = "Nome da chave SSH para acesso à instância"
}

variable "ec2_monitoring" {
  type        = bool
  description = "Habilitar monitoramento detalhado"
  default     = false
}

# ==================================================
# VARIÁVEIS PARA VPC E REDE
# ==================================================

variable "vpc_cidr" {
  type        = string
  description = "CIDR block da VPC (ex: 10.0.0.0/16)"
}

variable "availability_zones" {
  type        = list(string)
  description = "Lista de Availability Zones"
}

variable "private_subnets" {
  type        = list(string)
  description = "CIDRs das subnets privadas"
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDRs das subnets públicas"
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Habilitar NAT Gateway"
  default     = true
}

variable "enable_vpn_gateway" {
  type        = bool
  description = "Habilitar VPN Gateway"
  default     = false
}

# ==================================================
# TAGS GLOBAIS
# ==================================================

variable "project_tags" {
  type        = map(string)
  description = "Tags comuns para todos os recursos"
  default = {
    Project = "Challenge-IAC"
  }
}