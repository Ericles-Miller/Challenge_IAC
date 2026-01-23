# ==================================================
# SECURITY GROUP - Regras de firewall
# ==================================================
resource "aws_security_group" "ec2" {
  name        = "${var.instance_name}-sg"
  description = "Security Group para instancia EC2"
  vpc_id      = var.vpc_id

  # Se ssh_allowed_ips estiver vazio, essa regra não será criada
  dynamic "ingress" {
    for_each = length(var.ssh_allowed_ips) > 0 ? [1] : []
    content {
      description = "SSH from allowed IPs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_ips
    }
  }

  # Regra de entrada: HTTP (porta 80) - APENAS do Load Balancer
  ingress {
    description     = "HTTP from Load Balancer only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lb_security_group_id]  # ✅ Só aceita do Load Balancer
  }

  # Regra de entrada: HTTPS (porta 443) - APENAS do Load Balancer
  ingress {
    description     = "HTTPS from Load Balancer only"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.lb_security_group_id]  # ✅ Só aceita do Load Balancer
  }

  # Regra de saída: Permite todo tráfego (updates, APIs externas)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.instance_name}-sg"
    Environment = var.environment
  }
}

# ==================================================
# INSTÂNCIA EC2
# ==================================================
resource "aws_instance" "main" {
  ami           = var.ami_id              # Imagem do Linux
  instance_type = var.instance_type       # t3.small = 2GB RAM
  key_name      = var.key_name            # Chave SSH
  subnet_id     = var.subnet_id           # Subnet da VPC
  
  # Habilita IP público (necessário para acesso da internet)
  associate_public_ip_address = true
  
  # Associa o Security Group criado acima
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  # IAM Instance Profile (permissões da EC2)
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  # ==================================================
  # CRIPTOGRAFIA EBS - Volume Raiz
  # ==================================================
  root_block_device {
    volume_size           = var.ebs_volume_size       # Tamanho do disco (GB)
    volume_type           = var.ebs_volume_type       # Tipo: gp3 (SSD rápido)
    encrypted             = var.enable_ebs_encryption # CRIPTOGRAFIA HABILITADA
    delete_on_termination = true                      # Deletar ao terminar EC2
    
    tags = {
      Name        = "${var.instance_name}-root-volume"
      Environment = var.environment
      Encrypted   = var.enable_ebs_encryption ? "true" : "false"
    }
  }
  
  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}