# Configuração para ambiente de Desenvolvimento
environment  = "dev"
aws_profile  = "ericles-dev"
aws_region   = "us-east-1"
# ==================================================
# VPC e Rede
# ==================================================
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets    = ["10.0.10.0/24", "10.0.11.0/24"]
enable_nat_gateway = true
enable_vpn_gateway = false

# ==================================================
# EC2
# ==================================================
ec2_instance_type = "t3.small"                      # 2GB RAM
ec2_ami_id        = "ami-0e2c8caa4b6378d8c"         # Ubuntu 22.04 LTS (us-east-1)
ec2_key_name      = "challenge-iac-key"             # Chave SSH criada
ec2_monitoring    = false

# ==================================================
# Tags
# ==================================================
project_tags = {
  Project = "Challenge-IAC"
  Owner   = "Ericles"
}