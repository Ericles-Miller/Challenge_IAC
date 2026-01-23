# Configuração para ambiente de Produção
environment  = "prod"
aws_profile  = "ericles-prod"
aws_region   = "us-east-1"

# ==================================================
# VPC e Rede
# ==================================================
vpc_cidr           = "10.1.0.0/16"  # CIDR diferente de dev
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnets     = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnets    = ["10.1.10.0/24", "10.1.11.0/24"]
enable_nat_gateway = true
enable_vpn_gateway = false

# ==================================================
# EC2
# ==================================================
ec2_instance_type = "t3.medium"                     # Maior que dev (4GB RAM)
ec2_ami_id        = "ami-0e2c8caa4b6378d8c"         # Ubuntu 22.04 LTS (us-east-1)
ec2_key_name      = "challenge-iac-key-prod"        # Chave diferente para produção
ec2_monitoring    = true                            # Monitoramento habilitado em prod

# ==================================================
# SEGURANÇA SSH
# ==================================================
# Lista vazia [] = Você gerencia os IPs SSH manualmente pelo console AWS
ssh_allowed_ips = []

# Em produção, você pode definir IPs fixos da empresa:
# ssh_allowed_ips = [
#   "203.0.113.0/24",  # Range da empresa
# ]

# ==================================================
# Tags
# ==================================================
project_tags = {
  Project     = "Challenge-IAC"
  Owner       = "Ericles"
  Environment = "Production"
  CostCenter  = "Engineering"
}

# ==================================================
# CRIPTOGRAFIA EBS
# ==================================================
enable_ebs_encryption = true        # ✅ Criptografia habilitada (obrigatório em prod)
ebs_volume_size       = 10          # 10 GB (adequado para API com dados externos)
ebs_volume_type       = "gp3"       # SSD de última geração

# ==================================================
# IAM ROLE
# ==================================================
enable_iam_role  = true             # ✅ Habilitar IAM Role
enable_s3_access = false            # S3 desabilitado (altere se necessário)
s3_bucket_arns   = []               # Adicione ARNs se enable_s3_access = true
# Exemplo com S3:
# enable_s3_access = true
# s3_bucket_arns = [
#   "arn:aws:s3:::meu-bucket-prod",
#   "arn:aws:s3:::meu-bucket-backups"
# ]
