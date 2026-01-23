# Tutorial Completo - Passo a Passo do Projeto Challenge IAC

Este tutorial mostra **exatamente como o projeto foi construído**, desde o início até a configuração final do Load Balancer.

---

## 📚 Índice

1. [Fase 1: Configuração Inicial](#fase-1-configuração-inicial)
2. [Fase 2: Módulo VPC](#fase-2-módulo-vpc)
3. [Fase 3: Módulo EC2](#fase-3-módulo-ec2)
4. [Fase 4: Módulo Load Balancer](#fase-4-módulo-load-balancer)
5. [Fase 5: Alterações nos Módulos Anteriores](#fase-5-alterações-nos-módulos-anteriores)
6. [Fase 6: Deploy e Testes](#fase-6-deploy-e-testes)

---

## Fase 1: Configuração Inicial

### Passo 1.1: Criar estrutura de pastas

```bash
mkdir -p challenge_IAC/modules/{VPC,EC2,LOADBALANCER}
cd challenge_IAC
```

### Passo 1.2: Criar arquivo `provider.tf`

**Arquivo:** `provider.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

**O que faz:** Define a AWS como provedor e configura a região.

---

## Fase 2: Módulo VPC

### Passo 2.1: Criar arquivos do módulo VPC

#### Arquivo: `modules/VPC/variables.tf`

```hcl
variable "vpc_name" {
  description = "Nome da VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
}

variable "availability_zones" {
  description = "Lista de Availability Zones"
  type        = list(string)
}

variable "private_subnets" {
  description = "Lista de CIDRs para subnets privadas"
  type        = list(string)
}

variable "public_subnets" {
  description = "Lista de CIDRs para subnets públicas"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway"
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Habilitar VPN Gateway"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Ambiente (dev/prod)"
  type        = string
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}
```

#### Arquivo: `modules/VPC/main.tf`

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  tags = merge(
    var.tags,
    {
      Terraform   = "true"
      Environment = var.environment
    }
  )
}
```

**O que faz:** Usa o módulo oficial da AWS para criar VPC com subnets públicas e privadas em múltiplas AZs.

#### Arquivo: `modules/VPC/outputs.tf`

```hcl
output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnets
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC"
  value       = module.vpc.vpc_cidr_block
}
```

---

## Fase 3: Módulo EC2

### Passo 3.1: Criar arquivos do módulo EC2 (Versão Inicial)

> ⚠️ **IMPORTANTE:** Esta é a versão inicial do módulo EC2, ANTES da integração com o Load Balancer.

#### Arquivo: `modules/EC2/variables.tf`

```hcl
variable "instance_name" {
  description = "Nome da instância EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
}

variable "ami_id" {
  description = "ID da AMI"
  type        = string
}

variable "key_name" {
  description = "Nome da chave SSH"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet onde a EC2 será criada"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev/prod)"
  type        = string
}

variable "ssh_allowed_ips" {
  description = "Lista de IPs permitidos para SSH"
  type        = list(string)
  default     = []
}
```

#### Arquivo: `modules/EC2/main.tf` (VERSÃO INICIAL)

```hcl
# ==================================================
# SECURITY GROUP - Versão Inicial (SEM Load Balancer)
# ==================================================
resource "aws_security_group" "ec2" {
  name        = "${var.instance_name}-sg"
  description = "Security Group para instancia EC2"
  vpc_id      = var.vpc_id

  # Regra de entrada: SSH (porta 22)
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

  # Regra de entrada: HTTP (porta 80) - Aberto para testes
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ⚠️ Inicialmente aberto para internet
  }

  # Regra de entrada: HTTPS (porta 443) - Aberto para testes
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ⚠️ Inicialmente aberto para internet
  }

  # Regra de saída: Permite todo tráfego
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
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id
  
  associate_public_ip_address = true
  
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
```

**Observação:** Nesta versão inicial, a EC2 aceita tráfego HTTP/HTTPS de qualquer origem (`0.0.0.0/0`). Isso será alterado na Fase 5.

#### Arquivo: `modules/EC2/outputs.tf`

```hcl
output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.main.id
}

output "instance_public_ip" {
  description = "IP público da instância"
  value       = aws_instance.main.public_ip
}

output "security_group_id" {
  description = "ID do Security Group da EC2"
  value       = aws_security_group.ec2.id
}
```

### Passo 3.2: Criar arquivos raiz para usar VPC e EC2

#### Arquivo: `variables.tf` (Raiz)

```hcl
variable "environment" {
  description = "Ambiente (dev/prod)"
  type        = string
}

variable "vpc_name" {
  description = "Nome da VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
}

variable "availability_zones" {
  description = "Lista de Availability Zones"
  type        = list(string)
}

variable "private_subnets" {
  description = "Lista de CIDRs para subnets privadas"
  type        = list(string)
}

variable "public_subnets" {
  description = "Lista de CIDRs para subnets públicas"
  type        = list(string)
}

variable "instance_name" {
  description = "Nome da instância EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
}

variable "key_name" {
  description = "Nome da chave SSH"
  type        = string
}

variable "ssh_allowed_ips" {
  description = "Lista de IPs permitidos para SSH"
  type        = list(string)
  default     = []
}

variable "enable_monitoring" {
  description = "Habilitar monitoramento detalhado"
  type        = bool
  default     = false
}
```

#### Arquivo: `main.tf` (Raiz - VERSÃO INICIAL)

```hcl
# ==================================================
# MÓDULO VPC
# ==================================================
module "vpc" {
  source = "./modules/VPC"

  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  enable_nat_gateway = false
  enable_vpn_gateway = false
  environment        = var.environment

  tags = {
    Project = "challenge-iac"
  }
}

# ==================================================
# DATA SOURCE - AMI Ubuntu
# ==================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==================================================
# MÓDULO EC2
# ==================================================
module "ec2" {
  source = "./modules/EC2"

  instance_name   = var.instance_name
  instance_type   = var.instance_type
  ami_id          = data.aws_ami.ubuntu.id
  key_name        = var.key_name
  subnet_id       = module.vpc.public_subnets[0]
  vpc_id          = module.vpc.vpc_id
  environment     = var.environment
  ssh_allowed_ips = var.ssh_allowed_ips
}
```

#### Arquivo: `terraform.dev.tfvars`

```hcl
environment        = "dev"
vpc_name           = "vpc-dev"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
private_subnets    = ["10.0.3.0/24", "10.0.4.0/24"]
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]

instance_name      = "challenge-iac-dev"
instance_type      = "t3.small"
key_name           = "challenge-iac-key"
ssh_allowed_ips    = ["0.0.0.0/0"]
enable_monitoring  = false
```

#### Arquivo: `terraform.prod.tfvars`

```hcl
environment        = "prod"
vpc_name           = "vpc-prod"
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
private_subnets    = ["10.1.3.0/24", "10.1.4.0/24"]
public_subnets     = ["10.1.1.0/24", "10.1.2.0/24"]

instance_name      = "challenge-iac-prod"
instance_type      = "t3.medium"
key_name           = "challenge-iac-key-prod"
ssh_allowed_ips    = []  # Vazio = SSH desabilitado
enable_monitoring  = true
```

#### Arquivo: `outputs.tf` (Raiz)

```hcl
output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnets
}

output "ec2_instance_id" {
  description = "ID da instância EC2"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "IP público da EC2"
  value       = module.ec2.instance_public_ip
}
```

### Passo 3.3: Deploy inicial (VPC + EC2)

```bash
# Inicializar Terraform
terraform init

# Ver o que será criado
terraform plan -var-file="terraform.dev.tfvars"

# Criar recursos
terraform apply -var-file="terraform.dev.tfvars"
```

**Resultado:** VPC e EC2 criadas com sucesso! A EC2 está acessível diretamente pela internet.

---

## Fase 4: Módulo Load Balancer

### Passo 4.1: Criar arquivos do módulo Load Balancer

#### Arquivo: `modules/LOADBALANCER/variables.tf`

```hcl
variable "lb_name" {
  description = "Nome do Load Balancer"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "public_subnets" {
  description = "IDs das subnets públicas (mínimo 2)"
  type        = list(string)
}

variable "environment" {
  description = "Ambiente (dev/prod)"
  type        = string
}
```

#### Arquivo: `modules/LOADBALANCER/main.tf`

```hcl
# ==================================================
# PASSO 1: SECURITY GROUP DO LOAD BALANCER
# ==================================================
resource "aws_security_group" "lb_sg" {
  name        = "${var.lb_name}-sg"
  description = "Security Group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # Regra de entrada: HTTP (porta 80)
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de entrada: HTTPS (porta 443)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída: Permite todo tráfego
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.lb_name}-sg"
    Environment = var.environment
  }
}

# ==================================================
# PASSO 2: TARGET GROUP
# ==================================================
resource "aws_lb_target_group" "main" {
  name     = "${var.lb_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health Check
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.lb_name}-tg"
    Environment = var.environment
  }
}

# ==================================================
# PASSO 3: APPLICATION LOAD BALANCER
# ==================================================
resource "aws_lb" "main" {
  name               = var.lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = var.public_subnets

  enable_deletion_protection = false

  tags = {
    Name        = var.lb_name
    Environment = var.environment
  }
}

# ==================================================
# PASSO 4: LISTENER
# ==================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ==================================================
# PASSO 5: TARGET GROUP ATTACHMENT
# ==================================================
resource "aws_lb_target_group_attachment" "ec2" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = var.ec2_instance_id
  port             = 80
}
```

**O que faz:**
1. Cria Security Group que aceita HTTP/HTTPS da internet
2. Cria Target Group para agrupar EC2s e fazer health checks
3. Cria Application Load Balancer nas subnets públicas
4. Cria Listener para escutar porta 80 e encaminhar para Target Group
5. Registra a EC2 no Target Group

#### Arquivo: `modules/LOADBALANCER/outputs.tf`

```hcl
output "lb_dns_name" {
  description = "DNS do Load Balancer"
  value       = aws_lb.main.dns_name
}

output "lb_arn" {
  description = "ARN do Load Balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN do Target Group"
  value       = aws_lb_target_group.main.arn
}

output "lb_security_group_id" {
  description = "ID do Security Group do Load Balancer"
  value       = aws_security_group.lb_sg.id
}

output "lb_zone_id" {
  description = "Zone ID do Load Balancer"
  value       = aws_lb.main.zone_id
}
```

---

## Fase 5: Alterações nos Módulos Anteriores

> 🔄 **IMPORTANTE:** Agora precisamos fazer alterações nos módulos VPC e EC2 para integrá-los com o Load Balancer.

### Passo 5.1: Adicionar nova variável no módulo EC2

**Alteração 1:** Adicionar variável `lb_security_group_id` no arquivo `modules/EC2/variables.tf`

```hcl
# ADICIONAR NO FINAL DO ARQUIVO modules/EC2/variables.tf

variable "lb_security_group_id" {
  description = "ID do Security Group do Load Balancer"
  type        = string
}
```

**Por que:** A EC2 precisa saber o ID do Security Group do Load Balancer para aceitar tráfego APENAS dele.

---

### Passo 5.2: Modificar Security Group da EC2

**Alteração 2:** Modificar as regras de ingresso HTTP/HTTPS no arquivo `modules/EC2/main.tf`

**ANTES (aceitava qualquer origem):**

```hcl
# Regra de entrada: HTTP (porta 80) - Aberto para testes
ingress {
  description = "HTTP from anywhere"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ❌ Aberto para internet
}

# Regra de entrada: HTTPS (porta 443) - Aberto para testes
ingress {
  description = "HTTPS from anywhere"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ❌ Aberto para internet
}
```

**DEPOIS (aceita apenas do Load Balancer):**

```hcl
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
```

**O que mudou:**
- Trocamos `cidr_blocks` por `security_groups`
- Agora a EC2 só aceita tráfego HTTP/HTTPS se vier do Security Group do Load Balancer
- Isso aumenta drasticamente a segurança

---

### Passo 5.3: Adicionar módulo Load Balancer no arquivo raiz

**Alteração 3:** Adicionar variável `lb_name` no arquivo `variables.tf` (raiz)

```hcl
# ADICIONAR NO FINAL DO ARQUIVO variables.tf

variable "lb_name" {
  description = "Nome do Load Balancer"
  type        = string
}
```

**Alteração 4:** Atualizar arquivos tfvars

**terraform.dev.tfvars:**

```hcl
# ADICIONAR NO FINAL
lb_name = "challenge-iac-alb-dev"
```

**terraform.prod.tfvars:**

```hcl
# ADICIONAR NO FINAL
lb_name = "challenge-iac-alb-prod"
```

---

### Passo 5.4: Atualizar main.tf (raiz) com ordem correta

**Alteração 5:** Modificar arquivo `main.tf` (raiz) para incluir Load Balancer e passar o security_group_id

**VERSÃO FINAL DO main.tf:**

```hcl
# ==================================================
# MÓDULO VPC
# ==================================================
module "vpc" {
  source = "./modules/VPC"

  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  enable_nat_gateway = false
  enable_vpn_gateway = false
  environment        = var.environment

  tags = {
    Project = "challenge-iac"
  }
}

# ==================================================
# DATA SOURCE - AMI Ubuntu
# ==================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==================================================
# MÓDULO LOAD BALANCER - CRIADO PRIMEIRO ✅
# ==================================================
module "load_balancer" {
  source = "./modules/LOADBALANCER"

  lb_name        = var.lb_name
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  environment    = var.environment
  ec2_instance_id = module.ec2.instance_id  # Referência ao EC2
}

# ==================================================
# MÓDULO EC2 - CRIADO DEPOIS ✅
# ==================================================
module "ec2" {
  source = "./modules/EC2"

  instance_name         = var.instance_name
  instance_type         = var.instance_type
  ami_id                = data.aws_ami.ubuntu.id
  key_name              = var.key_name
  subnet_id             = module.vpc.public_subnets[0]
  vpc_id                = module.vpc.vpc_id
  environment           = var.environment
  ssh_allowed_ips       = var.ssh_allowed_ips
  lb_security_group_id  = module.load_balancer.lb_security_group_id  # ✅ NOVO
}
```

**⚠️ ATENÇÃO - PROBLEMA DE DEPENDÊNCIA CIRCULAR:**

Aqui temos um problema! O Load Balancer precisa do `ec2_instance_id` para registrar no Target Group, mas a EC2 precisa do `lb_security_group_id` para criar as regras de firewall.

**SOLUÇÃO:** Dividir o módulo Load Balancer em duas partes:

1. **Parte 1:** Criar Security Group, Load Balancer, Target Group e Listener
2. **Parte 2:** Registrar EC2 no Target Group (Target Group Attachment)

---

### Passo 5.5: Corrigir módulo Load Balancer (remover attachment)

**Alteração 6:** Modificar `modules/LOADBALANCER/main.tf`

**REMOVER estas linhas:**

```hcl
# ==================================================
# PASSO 5: TARGET GROUP ATTACHMENT
# ==================================================
resource "aws_lb_target_group_attachment" "ec2" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = var.ec2_instance_id
  port             = 80
}
```

**E remover a variável `ec2_instance_id` do `modules/LOADBALANCER/variables.tf`:**

```hcl
# DELETAR ESTA VARIÁVEL:
variable "ec2_instance_id" {
  description = "ID da instância EC2"
  type        = string
}
```

---

### Passo 5.6: Adicionar Target Group Attachment no arquivo raiz

**Alteração 7:** Adicionar o attachment diretamente no `main.tf` (raiz)

```hcl
# ADICIONAR NO FINAL DO ARQUIVO main.tf (raiz)

# ==================================================
# TARGET GROUP ATTACHMENT - Registra EC2 no Load Balancer
# ==================================================
resource "aws_lb_target_group_attachment" "ec2" {
  target_group_arn = module.load_balancer.target_group_arn
  target_id        = module.ec2.instance_id
  port             = 80
}
```

**Por que fizemos isso:**
- Agora o Load Balancer é criado ANTES da EC2 (para fornecer o security_group_id)
- A EC2 é criada DEPOIS (usando o lb_security_group_id)
- O attachment é feito por último (quando ambos já existem)

---

### Passo 5.7: Atualizar outputs.tf (raiz)

**Alteração 8:** Adicionar outputs do Load Balancer no `outputs.tf` (raiz)

```hcl
# ADICIONAR NO FINAL DO ARQUIVO outputs.tf

output "lb_dns_name" {
  description = "DNS do Load Balancer (use este para acessar a aplicação)"
  value       = module.load_balancer.lb_dns_name
}

output "lb_security_group_id" {
  description = "ID do Security Group do Load Balancer"
  value       = module.load_balancer.lb_security_group_id
}
```

---

## Fase 6: Deploy e Testes

### Passo 6.1: Atualizar a infraestrutura

```bash
# Ver as mudanças que serão aplicadas
terraform plan -var-file="terraform.dev.tfvars"
```

**O que você verá:**
- ✅ Security Group do Load Balancer será criado
- ✅ Load Balancer será criado
- ✅ Target Group será criado
- ✅ Listener será criado
- 🔄 Security Group da EC2 será modificado (regras HTTP/HTTPS)
- ✅ Target Group Attachment será criado

```bash
# Aplicar mudanças
terraform apply -var-file="terraform.dev.tfvars"
```

### Passo 6.2: Testar o Load Balancer

```bash
# Pegar o DNS do Load Balancer
terraform output lb_dns_name
```

**Saída exemplo:**
```
challenge-iac-alb-dev-1234567890.us-east-1.elb.amazonaws.com
```

```bash
# Testar acesso
curl http://challenge-iac-alb-dev-1234567890.us-east-1.elb.amazonaws.com
```

**Se você ver uma resposta do servidor web:** ✅ Funcionou!

**Se der erro 503 Service Unavailable:**
- O health check está falhando
- A EC2 não tem um servidor web rodando na porta 80
- Solução: Instalar Nginx ou Apache na EC2

### Passo 6.3: Instalar Nginx na EC2

```bash
# Conectar via SSH na EC2
ssh -i ~/.ssh/challenge-iac-key.pem ubuntu@<IP_DA_EC2>

# Instalar Nginx
sudo apt update
sudo apt install nginx -y

# Verificar se está rodando
sudo systemctl status nginx
```

Agora teste novamente o Load Balancer!

---

## 📊 Resumo das Alterações nos Módulos Anteriores

| Módulo | Arquivo | O que foi alterado | Motivo |
|--------|---------|-------------------|--------|
| **EC2** | `variables.tf` | Adicionada variável `lb_security_group_id` | Para receber o ID do SG do LB |
| **EC2** | `main.tf` | Regras HTTP/HTTPS mudaram de `cidr_blocks` para `security_groups` | Aceitar tráfego APENAS do LB |
| **LOADBALANCER** | `main.tf` | Removido `aws_lb_target_group_attachment` | Evitar dependência circular |
| **Raiz** | `variables.tf` | Adicionada variável `lb_name` | Configurar nome do Load Balancer |
| **Raiz** | `main.tf` | Módulo Load Balancer criado ANTES da EC2 | Fornecer `lb_security_group_id` |
| **Raiz** | `main.tf` | Adicionado `aws_lb_target_group_attachment` | Registrar EC2 no Target Group |
| **Raiz** | `main.tf` | Passado `lb_security_group_id` para módulo EC2 | Integrar EC2 com Load Balancer |
| **Raiz** | `outputs.tf` | Adicionados outputs do Load Balancer | Mostrar DNS do LB |

---

## 🔐 Melhorias de Segurança Implementadas

### Antes (Fase 3):
```
Internet → EC2 (porta 80/443 aberta para todos)
```

### Depois (Fase 5):
```
Internet → Load Balancer (porta 80/443 aberta)
         ↓
      Target Group (health checks)
         ↓
      EC2 (aceita APENAS do Load Balancer)
```

**Benefícios:**
1. ✅ EC2 não está mais exposta diretamente na internet
2. ✅ Tráfego passa por health checks antes de chegar na EC2
3. ✅ Logs centralizados no Load Balancer
4. ✅ Possibilidade de adicionar WAF no Load Balancer
5. ✅ Possibilidade de adicionar SSL/TLS no Load Balancer

---

## 🎯 Próximos Passos

1. **Adicionar HTTPS no Load Balancer**
   - Criar certificado no AWS Certificate Manager
   - Adicionar listener na porta 443
   - Redirecionar HTTP para HTTPS

2. **Adicionar Auto Scaling**
   - Criar Launch Template
   - Criar Auto Scaling Group
   - Configurar políticas de scaling

3. **Adicionar NAT Gateway**
   - Mover EC2 para subnets privadas
   - Configurar NAT Gateway nas subnets públicas
   - Atualizar route tables

4. **Adicionar RDS**
   - Criar subnet group para banco de dados
   - Configurar RDS em subnets privadas
   - Conectar EC2 ao RDS

5. **Adicionar CloudWatch Alarms**
   - Monitorar CPU da EC2
   - Monitorar health checks do Load Balancer
   - Configurar notificações SNS

---

## 📚 Comandos Úteis

```bash
# Ver outputs
terraform output

# Ver estado atual
terraform show

# Validar configuração
terraform validate

# Formatar código
terraform fmt -recursive

# Ver plano sem aplicar
terraform plan -var-file="terraform.dev.tfvars"

# Aplicar mudanças
terraform apply -var-file="terraform.dev.tfvars"

# Destruir tudo
terraform destroy -var-file="terraform.dev.tfvars"

# Ver recursos criados
terraform state list

# Ver detalhes de um recurso
terraform state show module.ec2.aws_instance.main
```

---

## 🐛 Troubleshooting

### Erro: "Error creating Target Group Attachment"
- **Causa:** EC2 não existe ainda
- **Solução:** Verificar se o módulo EC2 está antes do attachment no main.tf

### Erro: "503 Service Unavailable" ao acessar Load Balancer
- **Causa:** Health check está falhando
- **Solução:** Instalar servidor web (Nginx/Apache) na EC2

### Erro: "cycle: module.ec2 depends on module.load_balancer"
- **Causa:** Dependência circular
- **Solução:** Remover `ec2_instance_id` do módulo Load Balancer e criar attachment no arquivo raiz

### Erro: "Error: Invalid for_each argument"
- **Causa:** Lista vazia em `ssh_allowed_ips`
- **Solução:** Usar `dynamic` block com `for_each` no Security Group

---

## ✅ Checklist Final

- [x] VPC criada com subnets públicas e privadas
- [x] EC2 criada com Security Group restritivo
- [x] Load Balancer criado com Security Group
- [x] Target Group criado com health checks
- [x] Listener HTTP configurado
- [x] EC2 registrada no Target Group
- [x] Security Group da EC2 aceita tráfego APENAS do Load Balancer
- [x] SSH configurável via tfvars
- [x] Ambientes dev e prod separados
- [x] Outputs configurados para mostrar DNS do Load Balancer

---

**Parabéns! Você completou o tutorial! 🎉**
