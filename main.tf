# ==================================================
# MÓDULO VPC - Cria a rede virtual
# ==================================================
module "vpc" {
  source = "./modules/VPC"

  vpc_name           = "vpc-${var.environment}"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway
  environment        = var.environment

  tags = {
    Project = "Challenge-IAC"
  }
}

# ==================================================
# MÓDULO LOAD BALANCER - Distribui tráfego
# ==================================================
module "loadbalancer" {
  source = "./modules/LOADBALANCER"

  # Nome do Load Balancer
  lb_name = "alb-${var.environment}"

  # Rede - USA outputs do módulo VPC
  vpc_id         = module.vpc.vpc_id           # VPC onde o LB será criado
  public_subnets = module.vpc.public_subnets   # Subnets públicas (mínimo 2)

  # Instância EC2 para registrar no Target Group
  ec2_instance_id = module.ec2.instance_id

  # Ambiente
  environment = var.environment
}

# ==================================================
# MÓDULO EC2 - Cria a instância
# ==================================================
module "ec2" {
  source = "./modules/EC2"

  # Nome da instância baseado no ambiente
  instance_name = "app-server-${var.environment}"

  # Configurações da instância
  instance_type = var.ec2_instance_type
  ami_id        = var.ec2_ami_id
  key_name      = var.ec2_key_name
  monitoring    = var.ec2_monitoring

  # Configurações de rede - USA os outputs do módulo VPC
  vpc_id    = module.vpc.vpc_id                    # ← Pega o ID da VPC criada
  subnet_id = module.vpc.public_subnets[0]         # ← Pega a primeira subnet pública

  # Security Group do Load Balancer - USA output do módulo LB
  lb_security_group_id = module.loadbalancer.lb_security_group_id

  # IPs permitidos para SSH
  ssh_allowed_ips = var.ssh_allowed_ips

  # Ambiente
  environment = var.environment

  # Tags
  tags = merge(
    var.project_tags,
    {
      Name        = "app-server-${var.environment}"
      Environment = var.environment
    }
  )
}
