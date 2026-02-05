# Challenge IAC - Infraestrutura como Código na AWS

Projeto de Infrastructure as Code (IaC) usando Terraform para criar uma infraestrutura completa na AWS com VPC, EC2 e Application Load Balancer.

## 📋 Sumário

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Serviços Implementados](#serviços-implementados)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Como Usar](#como-usar)
- [Configuração de Ambientes](#configuração-de-ambientes)
- [Segurança](#segurança)
- [Próximos Passos](#próximos-passos)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

Este projeto implementa uma infraestrutura de rede completa na AWS utilizando Terraform, seguindo as melhores práticas de segurança e organização em módulos reutilizáveis.

### O que foi implementado:

- **VPC** com subnets públicas e privadas em múltiplas availability zones
- **EC2** com configurações de segurança restritivas
- **Application Load Balancer (ALB)** para distribuição de tráfego
- **Security Groups** configurados com princípio de menor privilégio
- **Separação de ambientes** (dev e prod) com configurações distintas

---

## 🏗️ Arquitetura

```
Internet
    |
    v
Internet Gateway
    |
    v
Application Load Balancer (ALB)
    |  (subnets públicas)
    |  - us-east-1a
    |  - us-east-1b
    |
    v
Target Group (Port 80)
    |
    v
EC2 Instance (subnets públicas)
    |
    v
Application (Nginx/API - a ser instalado)
```

### Fluxo de Tráfego:

1. **Usuário** → Acessa o DNS do Load Balancer
2. **ALB** → Recebe requisição nas portas 80/443
3. **Target Group** → Verifica saúde da EC2 (health checks)
4. **EC2** → Recebe tráfego apenas do Load Balancer
5. **Aplicação** → Processa requisição e retorna resposta

### Diagrama de Rede:

```
VPC (10.0.0.0/16 - dev | 10.1.0.0/16 - prod)
│
├── Subnets Públicas
│   ├── us-east-1a (10.0.1.0/24)
│   └── us-east-1b (10.0.2.0/24)
│
├── Subnets Privadas
│   ├── us-east-1a (10.0.3.0/24)
│   └── us-east-1b (10.0.4.0/24)
│
├── Internet Gateway
│   └── Rota: 0.0.0.0/0 → IGW
│
└── Security Groups
    ├── Load Balancer SG
    │   ├── Ingress: 0.0.0.0/0:80
    │   ├── Ingress: 0.0.0.0/0:443
    │   └── Egress: 0.0.0.0/0 (all)
    │
    └── EC2 SG
        ├── Ingress: LB-SG:80
        ├── Ingress: LB-SG:443
        ├── Ingress: SSH (dinâmico - configurável)
        └── Egress: 0.0.0.0/0 (all)
```

---

## 🛠️ Serviços Implementados

### 1. VPC (Virtual Private Cloud)

**Objetivo:** Criar uma rede isolada e segura na AWS.

**O que foi configurado:**

- **CIDR Block:** 
  - Dev: `10.0.0.0/16`
  - Prod: `10.1.0.0/16`
- **Subnets Públicas:** 2 subnets em AZs diferentes (us-east-1a, us-east-1b)
- **Subnets Privadas:** 2 subnets em AZs diferentes (para uso futuro)
- **Internet Gateway:** Permite comunicação com a internet
- **Route Tables:** 
  - Pública: Rota 0.0.0.0/0 → Internet Gateway
  - Privada: Apenas tráfego interno (preparada para NAT Gateway futuro)

**Por que 2 Availability Zones?**
- **Alta disponibilidade:** Se uma AZ cair, a outra continua funcionando
- **Requisito do ALB:** Load Balancers exigem no mínimo 2 AZs

**Arquivo:** `modules/VPC/main.tf`

**Recursos criados:**
- `aws_vpc`
- `aws_subnet` (4 subnets)
- `aws_internet_gateway`
- `aws_route_table` (2 tabelas)
- `aws_route_table_association` (4 associações)

---

### 2. EC2 (Elastic Compute Cloud)

**Objetivo:** Instância de servidor onde a aplicação será executada.

**O que foi configurado:**

- **Tipo de Instância:**
  - Dev: `t3.small` (2 vCPUs, 2GB RAM)
  - Prod: `t3.medium` (2 vCPUs, 4GB RAM)
- **AMI:** Ubuntu 22.04 LTS (automático via data source)
- **Subnet:** Subnet pública na us-east-1a
- **IP Público:** Sim (para acesso SSH e testes)
- **Monitoring:**
  - Dev: Desabilitado
  - Prod: Habilitado (métricas detalhadas)
- **Key Pair:** 
  - Dev: `challenge-iac-key`
  - Prod: `challenge-iac-key-prod`

**Security Group da EC2:**

| Tipo | Porta | Origem | Descrição |
|------|-------|--------|-----------|
| Ingress | 80 | Load Balancer SG | HTTP apenas do ALB |
| Ingress | 443 | Load Balancer SG | HTTPS apenas do ALB |
| Ingress | 22 | Configurável (tfvars) | SSH (dinâmico) |
| Egress | All | 0.0.0.0/0 | Saída para internet |

**Configuração Dinâmica de SSH:**

```hcl
# SSH só é criado se houver IPs em ssh_allowed_ips
dynamic "ingress" {
  for_each = length(var.ssh_allowed_ips) > 0 ? [1] : []
  content {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_ips
  }
}
```

**Por que a EC2 só aceita tráfego do Load Balancer?**
- **Segurança:** EC2 não fica exposta diretamente na internet
- **Controle:** Todo tráfego passa pelo ALB (logs, WAF, etc)
- **Isolamento:** Aplicação protegida de acessos diretos

**Arquivo:** `modules/EC2/main.tf`

**Recursos criados:**
- `aws_instance`
- `aws_security_group` (EC2)

---

### 3. Application Load Balancer (ALB)

**Objetivo:** Distribuir tráfego HTTP/HTTPS para as instâncias EC2 e fazer health checks.

**O que foi configurado:**

#### 3.1 Load Balancer Security Group

**Função:** Controlar o tráfego de entrada e saída do ALB.

| Tipo | Porta | Origem | Descrição |
|------|-------|--------|-----------|
| Ingress | 80 | 0.0.0.0/0 | HTTP de qualquer origem |
| Ingress | 443 | 0.0.0.0/0 | HTTPS de qualquer origem |
| Egress | All | 0.0.0.0/0 | Saída para internet |

**Por que Egress 0.0.0.0/0?**
- Evita dependência circular com EC2 Security Group
- Segurança é garantida pelo Security Group da EC2 (que só aceita do ALB)

#### 3.2 Target Group

**Função:** Agrupar instâncias EC2 que receberão tráfego do ALB.

**Configuração:**
```hcl
Port: 80
Protocol: HTTP
VPC: Mesma VPC da EC2

Health Check:
  - Path: "/"
  - Interval: 30 segundos
  - Timeout: 5 segundos
  - Healthy Threshold: 2 (2 checks OK = saudável)
  - Unhealthy Threshold: 2 (2 checks falhos = não saudável)
```

**O que é Health Check?**
- O ALB faz requisições periódicas para o path `/` da EC2
- Se receber HTTP 200, marca como "Healthy"
- Se falhar 2 vezes seguidas, marca como "Unhealthy" e para de enviar tráfego

#### 3.3 Application Load Balancer

**Configuração:**
```hcl
Type: application
Scheme: internet-facing (público)
IP Address Type: ipv4
Subnets: 2 subnets públicas (us-east-1a, us-east-1b)
Security Groups: Load Balancer SG
```

**Características:**
- **DNS automático:** AWS fornece um DNS (ex: `alb-dev-*.us-east-1.elb.amazonaws.com`)
- **Distribuição:** Roteia tráfego apenas para targets "Healthy"
- **Multi-AZ:** Se uma AZ cair, continua funcionando na outra

#### 3.4 Listener

**Função:** "Ouvir" requisições na porta 80 e encaminhar para o Target Group.

**Configuração:**
```hcl
Port: 80
Protocol: HTTP
Default Action: Forward para Target Group
```

**Fluxo:**
```
Usuário faz requisição → Listener porta 80 → Target Group → EC2 saudável
```

#### 3.5 Target Group Attachment

**Função:** Registrar a instância EC2 no Target Group.

**Configuração:**
```hcl
Target Group: Main TG
Target ID: ID da EC2
Port: 80
```

**Arquivo:** `modules/LOADBALANCER/main.tf`

**Recursos criados:**
- `aws_security_group` (Load Balancer)
- `aws_lb_target_group`
- `aws_lb`
- `aws_lb_listener`
- `aws_lb_target_group_attachment`

---

## 📁 Estrutura do Projeto

```
challenge_IAC/
│
├── main.tf                    # Orquestração dos módulos
├── variables.tf               # Variáveis do root module
├── outputs.tf                 # Outputs do root module
├── provider.tf                # Configuração do provider AWS
├── terraform.dev.tfvars       # Valores para ambiente dev
├── terraform.prod.tfvars      # Valores para ambiente prod
├── README.md                  # Esta documentação
│
└── modules/
    │
    ├── VPC/
    │   ├── main.tf           # Recursos da VPC
    │   ├── variables.tf      # Inputs do módulo VPC
    │   └── outputs.tf        # Outputs do módulo VPC
    │
    ├── EC2/
    │   ├── main.tf           # Recursos da EC2
    │   ├── variables.tf      # Inputs do módulo EC2
    │   └── outputs.tf        # Outputs do módulo EC2
    │
    └── LOADBALANCER/
        ├── main.tf           # Recursos do Load Balancer
        ├── variables.tf      # Inputs do módulo LB
        └── outputs.tf        # Outputs do módulo LB
```

### Organização dos Módulos

**Por que usar módulos?**
- **Reutilização:** Mesma VPC pode ser usada em vários projetos
- **Manutenção:** Mudanças isoladas sem afetar outros recursos
- **Clareza:** Cada módulo tem responsabilidade única
- **Testes:** Fácil testar cada módulo separadamente

### Ordem de Criação (Dependências)

```
1. VPC
   ↓
2. Load Balancer (precisa de VPC ID e subnets)
   ↓
3. EC2 (precisa de VPC ID, subnet ID, e LB Security Group)
```

**Configurado em:** `main.tf`

```hcl
module "vpc" { ... }

module "loadbalancer" {
  # Depende dos outputs da VPC
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
}

module "ec2" {
  # Depende dos outputs da VPC e Load Balancer
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.vpc.public_subnet_ids[0]
  lb_security_group_id  = module.loadbalancer.lb_security_group_id
}
```

---

## ✅ Pré-requisitos

### 1. Ferramentas Necessárias

- **Terraform:** >= 1.0
  ```bash
  terraform version
  ```

- **AWS CLI:** Configurado com credenciais
  ```bash
  aws --version
  aws configure list
  ```

### 2. Credenciais AWS

Você precisa ter profiles AWS configurados:

**Dev:**
```bash
aws configure --profile ericles-dev
# AWS Access Key ID: [sua_key]
# AWS Secret Access Key: [seu_secret]
# Default region: us-east-1
# Default output format: json
```

**Prod:**
```bash
aws configure --profile ericles-prod
```

### 3. Key Pair

**Dev:** Criar key pair chamada `challenge-iac-key`:
```bash
aws ec2 create-key-pair \
  --key-name challenge-iac-key \
  --profile ericles-dev \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/challenge-iac-key.pem

chmod 400 ~/.ssh/challenge-iac-key.pem
```

**Prod:** Criar key pair chamada `challenge-iac-key-prod`:
```bash
aws ec2 create-key-pair \
  --key-name challenge-iac-key-prod \
  --profile ericles-prod \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/challenge-iac-key-prod.pem

chmod 400 ~/.ssh/challenge-iac-key-prod.pem
```

### 4. Backend S3 (Opcional)

Se quiser usar S3 backend para state remoto, crie o bucket:

```bash
aws s3 mb s3://seu-bucket-terraform-state \
  --profile ericles-dev \
  --region us-east-1
```

E configure em `provider.tf`:
```hcl
terraform {
  backend "s3" {
    bucket  = "seu-bucket-terraform-state"
    key     = "challenge-iac/terraform.tfstate"
    region  = "us-east-1"
    profile = "ericles-dev"
  }
}
```

---

## 🚀 Como Usar

### 1. Clone o Repositório

```bash
git clone https://github.com/Ericles-Miller/Challenge_IAC.git
cd challenge_IAC
```

### 2. Inicializar Terraform

```bash
terraform init
```

Este comando:
- Baixa o provider AWS
- Configura o backend (se configurado)
- Inicializa os módulos

### 3. Validar Configuração

```bash
terraform validate
```

Verifica se a sintaxe está correta.

### 4. Planejar Deploy (Dev)

```bash
terraform plan -var-file="terraform.dev.tfvars"
```

Este comando mostra:
- Recursos que serão criados
- Mudanças que serão feitas
- Possíveis erros

### 5. Aplicar Infraestrutura (Dev)

```bash
terraform apply -var-file="terraform.dev.tfvars"
```

Digite `yes` quando solicitado.

**Tempo estimado:** 3-5 minutos

### 6. Verificar Outputs

```bash
terraform output
```

Você verá:
```
ec2_public_ip = "54.90.219.117"
lb_dns_name = "alb-dev-123456789.us-east-1.elb.amazonaws.com"
lb_url = "http://alb-dev-123456789.us-east-1.elb.amazonaws.com"
ssh_connection = "ssh -i ~/.ssh/challenge-iac-key.pem ubuntu@54.90.219.117"
vpc_id = "vpc-0123456789abcdef"
```

### 7. Acessar EC2 via SSH

```bash
# Copiar comando do output
terraform output -raw ssh_connection | sh
```

Ou manualmente:
```bash
ssh -i ~/.ssh/challenge-iac-key.pem ubuntu@<EC2_PUBLIC_IP>
```

### 8. Instalar Aplicação (Nginx - exemplo)

**Dentro da EC2:**
```bash
# Atualizar sistema
sudo apt update

# Instalar Nginx
sudo apt install -y nginx

# Verificar se está rodando
sudo systemctl status nginx

# Testar localmente
curl localhost
```

**Verificar Health Check:**
- Aguarde 30-60 segundos
- Acesse AWS Console → EC2 → Target Groups
- Verifique se o status da EC2 é "Healthy"

### 9. Testar Load Balancer

**No seu navegador:**
```
http://<LB_DNS_NAME>
```

Você deve ver a página padrão do Nginx.

### 10. Destruir Infraestrutura (quando necessário)

```bash
terraform destroy -var-file="terraform.dev.tfvars"
```

Digite `yes` quando solicitado.

**⚠️ Cuidado:** Isso remove TODOS os recursos criados!

---

## ⚙️ Configuração de Ambientes

### Desenvolvimento (dev)

**Arquivo:** `terraform.dev.tfvars`

```hcl
# Identificação
environment = "dev"
aws_profile = "ericles-dev"
aws_region  = "us-east-1"

# VPC
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]

# EC2
ec2_instance_type = "t3.small"
ec2_key_name      = "challenge-iac-key"
enable_monitoring = false

# Security
ssh_allowed_ips = []  # Gerenciar manualmente via console

# Tags
tags = {
  Environment = "dev"
  Project     = "challenge-iac"
  ManagedBy   = "Terraform"
}
```

**Características:**
- Menor custo (t3.small)
- Monitoring desabilitado
- CIDR 10.0.0.0/16

### Produção (prod)

**Arquivo:** `terraform.prod.tfvars`

```hcl
# Identificação
environment = "prod"
aws_profile = "ericles-prod"
aws_region  = "us-east-1"

# VPC
vpc_cidr            = "10.1.0.0/16"  # Diferente do dev
public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]

# EC2
ec2_instance_type = "t3.medium"  # Maior que dev
ec2_key_name      = "challenge-iac-key-prod"  # Key diferente
enable_monitoring = true  # Habilitado em prod

# Security
ssh_allowed_ips = []  # Gerenciar manualmente via console

# Tags
tags = {
  Environment = "prod"
  Project     = "challenge-iac"
  ManagedBy   = "Terraform"
}
```

**Características:**
- Maior performance (t3.medium)
- Monitoring habilitado
- CIDR 10.1.0.0/16 (evita conflito com dev)
- Key pair separada

### Comparação Dev vs Prod

| Item | Dev | Prod |
|------|-----|------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| Tipo EC2 | t3.small (2GB) | t3.medium (4GB) |
| Monitoring | Desabilitado | Habilitado |
| Key Pair | challenge-iac-key | challenge-iac-key-prod |
| AWS Profile | ericles-dev | ericles-prod |

---

## 🔒 Segurança

### Princípios Implementados

#### 1. Princípio do Menor Privilégio

**EC2:**
- Aceita HTTP/HTTPS **apenas** do Load Balancer
- SSH configurável (pode ser totalmente bloqueado)
- Não exposta diretamente na internet

**Load Balancer:**
- Aceita tráfego de qualquer origem (público)
- Encaminha apenas para targets saudáveis

#### 2. Defesa em Profundidade

```
Camada 1: Internet → Load Balancer (SG: 80/443 público)
Camada 2: Load Balancer → EC2 (SG: apenas do LB)
Camada 3: EC2 → Aplicação (configuração da app)
```

#### 3. Segregação de Rede

- **Subnets Públicas:** Load Balancer e EC2 (temporário)
- **Subnets Privadas:** Preparadas para banco de dados/backend

### Configuração de SSH

**Três Opções:**

#### Opção 1: Bloqueio Total (Mais Seguro)
```hcl
# terraform.dev.tfvars
ssh_allowed_ips = []
```
Resultado: Nenhuma regra SSH criada, acesso apenas via Session Manager.

#### Opção 2: IPs Específicos (Recomendado para Dev)
```hcl
# terraform.dev.tfvars
ssh_allowed_ips = ["203.0.113.0/32", "198.51.100.0/32"]
```
Resultado: SSH apenas dos IPs especificados.

#### Opção 3: Gerenciamento Manual via Console (Atual)
```hcl
# terraform.dev.tfvars
ssh_allowed_ips = []
```
- Não cria regra no Terraform
- Adicionar IPs manualmente no Console AWS
- Terraform não sobrescreve regras manuais

**Para adicionar IP manualmente:**
1. AWS Console → EC2 → Security Groups
2. Selecionar Security Group da EC2
3. Edit Inbound Rules → Add Rule
4. Type: SSH, Port: 22, Source: My IP

### Security Groups - Regras Detalhadas

#### Load Balancer Security Group

**Inbound:**
```hcl
# HTTP de qualquer origem
Port: 80
Protocol: TCP
Source: 0.0.0.0/0
Description: "Allow HTTP from internet"

# HTTPS de qualquer origem
Port: 443
Protocol: TCP
Source: 0.0.0.0/0
Description: "Allow HTTPS from internet"
```

**Outbound:**
```hcl
# Todo tráfego permitido
Protocol: All
Destination: 0.0.0.0/0
Description: "Allow all outbound traffic"
```

#### EC2 Security Group

**Inbound:**
```hcl
# HTTP apenas do Load Balancer
Port: 80
Protocol: TCP
Source: sg-XXXXXXXXX (Load Balancer SG)
Description: "Allow HTTP from Load Balancer only"

# HTTPS apenas do Load Balancer
Port: 443
Protocol: TCP
Source: sg-XXXXXXXXX (Load Balancer SG)
Description: "Allow HTTPS from Load Balancer only"

# SSH (opcional - dinâmico)
Port: 22
Protocol: TCP
Source: Configurado em ssh_allowed_ips
Description: "SSH access (if configured)"
```

**Outbound:**
```hcl
# Todo tráfego permitido (para updates, etc)
Protocol: All
Destination: 0.0.0.0/0
Description: "Allow all outbound traffic"
```

### Por que Egress 0.0.0.0/0?

**Motivos:**
1. **Evitar Circular Dependency:** LB e EC2 não podem referenciar um ao outro na criação
2. **Flexibilidade:** EC2 pode fazer updates, instalar pacotes
3. **Segurança mantida:** Ingress da EC2 ainda é restrito ao LB

**Alternativa mais restrita (futuro):**
- Usar NAT Gateway nas subnets privadas
- Mover EC2 para subnet privada
- Egress apenas via NAT Gateway

### Gerenciamento de Secrets e Credenciais

O projeto implementa **boas práticas de segurança** para gerenciamento de informações sensíveis, mantendo credenciais **fora do código Terraform**:

#### 1. Variáveis Sensíveis

Todas as informações sensíveis são marcadas como `sensitive = true` no Terraform:

```hcl
# variables.tf
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true  # ← Não aparece em logs/outputs
}
```

#### 2. Arquivos .tfvars (Gitignored)

Valores sensíveis ficam em arquivos `.tfvars` que **não são commitados** no Git:

```bash
# .gitignore
*.tfvars
!terraform.example.tfvars
```

**Estrutura:**
```
terraform.dev.tfvars      # ← Gitignored (valores reais)
terraform.prod.tfvars     # ← Gitignored (valores reais)
terraform.example.tfvars  # ← Commitado (template sem valores)
```

#### 3. AWS Profiles (Credenciais AWS)

Credenciais AWS são gerenciadas via **AWS CLI profiles**, nunca no código:

```bash
# ~/.aws/credentials
[ericles-dev]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[ericles-prod]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

**Uso no Terraform:**
```hcl
# provider.tf
provider "aws" {
  profile = var.aws_profile  # "ericles-dev" ou "ericles-prod"
  region  = var.aws_region
}
```

#### 4. IAM Roles (Permissões EC2)

EC2 utiliza **IAM Instance Profile** ao invés de credenciais hardcoded:

```hcl
# EC2 tem IAM role anexado
resource "aws_instance" "main" {
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  # Não precisa de access keys!
}
```

**Benefícios:**
- ✅ Credenciais rotacionadas automaticamente pela AWS
- ✅ Sem risco de vazar keys no código
- ✅ Controle granular via IAM policies

#### 5. Variáveis de Ambiente (Aplicação)

Para secrets da aplicação (JWT, API keys), use variáveis de ambiente na EC2:

```bash
# Na EC2, criar arquivo .env
cat > /home/ubuntu/app/.env <<EOF
JWT_SECRET=seu-jwt-secret-aqui
API_KEY=sua-api-key-aqui
NODE_ENV=production
EOF

# Não commitar .env no Git
echo ".env" >> .gitignore
```

#### 6. Alternativas para Produção

Para ambientes de produção, considere:

**AWS Secrets Manager:**
- Rotação automática de secrets
- Auditoria completa (CloudTrail)
- Integração com RDS

**AWS Systems Manager Parameter Store:**
- Mais barato que Secrets Manager
- Ótimo para configurações não-rotacionáveis
- Suporta criptografia com KMS

**Exemplo de uso (futuro):**
```hcl
# Criar secret no AWS Secrets Manager
resource "aws_secretsmanager_secret" "api_keys" {
  name = "${var.environment}-api-keys"
}

# Na EC2, ler via AWS SDK
aws secretsmanager get-secret-value \
  --secret-id dev-api-keys \
  --query SecretString
```

#### 7. Checklist de Segurança

- [x] Credenciais AWS via profiles (não no código)
- [x] Variáveis sensíveis marcadas como `sensitive = true`
- [x] Arquivos `.tfvars` no `.gitignore`
- [x] EC2 usa IAM roles (não access keys)
- [x] SSH keys não commitadas no Git
- [x] Security Groups restritivos
- [x] Criptografia EBS habilitada
- [ ] Secrets Manager (implementar se necessário)
- [ ] CloudTrail habilitado (auditoria)
- [ ] MFA em contas AWS

---

## 🔄 Próximos Passos

### Curto Prazo (Funcionalidades Básicas)

1. **Instalar Aplicação na EC2**
   ```bash
   # Nginx (simples)
   sudo apt update && sudo apt install -y nginx
   
   # Ou API (Node.js, Python, etc)
   ```

2. **Configurar HTTPS**
   - Obter certificado SSL no AWS Certificate Manager
   - Adicionar listener HTTPS (porta 443) no Load Balancer
   - Redirecionar HTTP → HTTPS

3. **Habilitar Logs do Load Balancer**
   - Criar bucket S3 para logs
   - Habilitar access logs no ALB

### Médio Prazo (Escalabilidade)

4. **Auto Scaling Group**
   - Criar Launch Template com AMI customizada
   - Configurar Auto Scaling (min 2, max 4 instâncias)
   - Remover EC2 manual

5. **Mover EC2 para Subnet Privada**
   - Criar NAT Gateway nas subnets públicas
   - Mover instâncias para subnets privadas
   - Acesso apenas via Load Balancer

6. **Adicionar RDS (Banco de Dados)**
   - Criar subnet group nas subnets privadas
   - Deploy RDS Multi-AZ
   - Configurar Security Group (aceita apenas da EC2)

### Longo Prazo (Produção)

7. **Monitoramento e Alertas**
   - CloudWatch Dashboards
   - Alarmes (CPU, memória, health checks)
   - SNS para notificações

8. **CI/CD Pipeline**
   - GitHub Actions ou CodePipeline
   - Deploy automático via terraform apply
   - Testes automatizados

9. **WAF (Web Application Firewall)**
   - Proteger contra SQL Injection, XSS
   - Rate limiting
   - Geo-blocking se necessário

10. **Backup e Disaster Recovery**
    - Snapshots automáticos da EC2
    - Backup do RDS
    - Terraform state em S3 com versionamento

---

## 🔧 Troubleshooting

### Problema 1: Health Check Failing

**Sintoma:**
- Target Group mostra EC2 como "Unhealthy"
- Ao acessar Load Balancer: 503 Service Unavailable

**Causa:**
- Nenhuma aplicação rodando na porta 80 da EC2

**Solução:**
```bash
# SSH na EC2
ssh -i ~/.ssh/challenge-iac-key.pem ubuntu@<EC2_IP>

# Instalar Nginx
sudo apt update
sudo apt install -y nginx

# Verificar se está rodando
curl localhost

# Verificar no Target Group (aguarde 30s)
```

### Problema 2: Não Consigo Conectar via SSH

**Sintoma:**
```
ssh: connect to host X.X.X.X port 22: Connection timed out
```

**Possíveis Causas:**
1. `ssh_allowed_ips` está vazio (nenhuma regra SSH criada)
2. Seu IP não está na lista
3. Security Group não tem regra SSH

**Solução:**
```bash
# Opção 1: Adicionar seu IP no tfvars
# terraform.dev.tfvars
ssh_allowed_ips = ["SEU_IP/32"]

# Aplicar mudança
terraform apply -var-file="terraform.dev.tfvars"

# Opção 2: Adicionar manualmente no console
# AWS Console → EC2 → Security Groups → Edit Inbound Rules
# Add Rule: SSH, Port 22, Source: My IP
```

### Problema 3: Terraform Apply Falha com Circular Dependency

**Sintoma:**
```
Error: Cycle: module.loadbalancer, module.ec2
```

**Causa:**
- Load Balancer referencia EC2 Security Group
- EC2 referencia Load Balancer Security Group

**Solução (Já Implementada):**
- Load Balancer usa egress `0.0.0.0/0`
- EC2 referencia Load Balancer SG no ingress
- Não há ciclo porque LB não depende da EC2

### Problema 4: Cannot Access Load Balancer DNS

**Sintoma:**
- DNS não resolve ou não responde

**Possíveis Causas:**
1. Load Balancer ainda está sendo criado (aguarde 2-3 minutos)
2. EC2 está "Unhealthy" (veja Problema 1)
3. Security Group do LB não permite porta 80

**Solução:**
```bash
# Verificar status do Load Balancer
aws elbv2 describe-load-balancers \
  --profile ericles-dev \
  --query 'LoadBalancers[0].State'

# Verificar targets
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --profile ericles-dev
```

### Problema 5: Terraform State Lock

**Sintoma:**
```
Error: Error acquiring the state lock
```

**Causa:**
- Outro processo terraform rodando
- Lock não foi liberado de execução anterior

**Solução:**
```bash
# Se backend S3 com DynamoDB
terraform force-unlock <LOCK_ID>

# Ou aguardar alguns minutos
```

### Problema 6: Insufficient Permissions

**Sintoma:**
```
Error: UnauthorizedOperation: You are not authorized to perform this operation
```

**Causa:**
- IAM user/role não tem permissões necessárias

**Permissões Necessárias:**
- EC2: Full Access
- VPC: Full Access
- ELB: Full Access
- S3: Read/Write (se usar backend S3)

**Solução:**
- Adicionar policy `PowerUserAccess` ou policies específicas no IAM

### Problema 7: Key Pair Not Found

**Sintoma:**
```
Error: InvalidKeyPair.NotFound: The key pair 'challenge-iac-key' does not exist
```

**Solução:**
```bash
# Criar key pair
aws ec2 create-key-pair \
  --key-name challenge-iac-key \
  --profile ericles-dev \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/challenge-iac-key.pem

chmod 400 ~/.ssh/challenge-iac-key.pem
```

---

## 📚 Recursos Adicionais

### Documentação Oficial

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC](https://docs.aws.amazon.com/vpc/)
- [AWS EC2](https://docs.aws.amazon.com/ec2/)
- [AWS Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/)

### Comandos Úteis

```bash
# Ver todos os outputs
terraform output

# Ver output específico
terraform output lb_dns_name

# Ver output sem formatação (para scripts)
terraform output -raw ec2_public_ip

# Formatar código
terraform fmt -recursive

# Ver state atual
terraform show

# Listar recursos no state
terraform state list

# Ver detalhes de um recurso
terraform state show module.ec2.aws_instance.main

# Importar recurso existente
terraform import module.vpc.aws_vpc.main vpc-xxxxxxxxx

# Atualizar providers
terraform init -upgrade
```

### Custos Estimados (us-east-1)

**Desenvolvimento:**
- EC2 t3.small: ~$15/mês
- Application Load Balancer: ~$20/mês
- Data Transfer: Variável
- **Total aproximado: $35-40/mês**

**Produção:**
- EC2 t3.medium: ~$30/mês
- Application Load Balancer: ~$20/mês
- Data Transfer: Variável
- Monitoring: ~$5/mês
- **Total aproximado: $55-65/mês**

**⚠️ Nota:** Valores aproximados. Use AWS Cost Calculator para estimativas precisas.

---

## 👥 Contribuindo

Se quiser melhorar este projeto:

1. Fork o repositório
2. Crie uma branch: `git checkout -b feature/nova-feature`
3. Commit suas mudanças: `git commit -m 'Add nova feature'`
4. Push para a branch: `git push origin feature/nova-feature`
5. Abra um Pull Request

---

## 📄 Licença

Este projeto é de código aberto e está disponível sob a licença MIT.

---

## ✉️ Contato

- **GitHub:** [@Ericles-Miller](https://github.com/Ericles-Miller)
- **Projeto:** [Challenge_IAC](https://github.com/Ericles-Miller/Challenge_IAC)

---

**Última atualização:** 22 de janeiro de 2026