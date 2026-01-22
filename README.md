# Challenge IAC - Infraestrutura como Código com Terraform

Projeto de infraestrutura na AWS usando Terraform para criar e gerenciar recursos de forma automatizada e versionada.

## 📋 Índice

- [Descrição do Projeto](#descrição-do-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Configuração Passo a Passo](#configuração-passo-a-passo)
- [Como Usar](#como-usar)
- [Recursos Criados](#recursos-criados)
- [Ambientes](#ambientes)
- [Próximos Passos](#próximos-passos)

---

## 📝 Descrição do Projeto

Este projeto implementa uma infraestrutura básica na AWS com:
- **VPC** (Virtual Private Cloud) com subnets públicas e privadas
- **EC2** (instância Ubuntu 22.04 LTS)
- **Internet Gateway** para acesso à internet
- **NAT Gateways** para subnets privadas
- Configurações separadas para múltiplos ambientes (dev, prod, staging)

---

## ✅ Pré-requisitos

Antes de começar, você precisa ter instalado:

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configurado
- Conta AWS com credenciais configuradas
- Chave SSH para acesso às instâncias EC2

### Configurar AWS CLI

```bash
aws configure --profile ericles-dev
# Informe: Access Key, Secret Key, região (us-east-1), output format (json)
```

---

## 📁 Estrutura do Projeto

```
challenge_IAC/
├── main.tf                    # Chamada dos módulos principais
├── variables.tf               # Variáveis do projeto
├── outputs.tf                 # Outputs visíveis após apply
├── provider.tf                # Configuração do provider AWS
├── terraform.dev.tfvars       # Valores específicos para DEV
├── terraform.prod.tfvars      # Valores específicos para PROD
├── terraform.staging.tfvars   # Valores específicos para STAGING
└── modules/
    ├── VPC/
    │   ├── main.tf           # Recursos da VPC
    │   ├── variables.tf      # Variáveis do módulo VPC
    │   └── outputs.tf        # Outputs da VPC
    └── EC2/
        ├── main.tf           # Recurso EC2
        ├── variables.tf      # Variáveis do módulo EC2
        └── outputs.tf        # Outputs do EC2
```

---

## 🚀 Configuração Passo a Passo

### **1. Criar Chave SSH**

```bash
# Criar chave SSH local
ssh-keygen -t rsa -b 4096 -f ~/.ssh/challenge-iac-key -N "" -C "challenge-iac-dev"

# Ver a chave pública
cat ~/.ssh/challenge-iac-key.pub
```

### **2. Importar Chave SSH na AWS**

**Opção A: Via Console AWS**
1. Acesse: https://console.aws.amazon.com/ec2/
2. Menu: Network & Security → Key Pairs
3. Actions → Import key pair
4. Nome: `challenge-iac-key`
5. Cole o conteúdo de `~/.ssh/challenge-iac-key.pub`

**Opção B: Via AWS CLI**
```bash
aws ec2 import-key-pair \
  --key-name "challenge-iac-key" \
  --public-key-material fileb://~/.ssh/challenge-iac-key.pub \
  --region us-east-1 \
  --profile ericles-dev
```

### **3. Configurar Módulo VPC**

Criar `modules/VPC/main.tf`:
```terraform
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

Criar `modules/VPC/variables.tf` com as variáveis necessárias.

Criar `modules/VPC/outputs.tf`:
```terraform
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}
```

### **4. Configurar Módulo EC2**

Criar `modules/EC2/main.tf`:

**A) Primeiro, criar o Security Group para controlar o tráfego:**

```terraform
# Security Group - Firewall virtual para a instância EC2
resource "aws_security_group" "ec2" {
  name        = "allow-ssh-http-https-${var.instance_name}"
  description = "Security group for EC2 instance - allows SSH, HTTP and HTTPS"
  vpc_id      = var.vpc_id

  # Regra de entrada - SSH (porta 22)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ⚠️ Em produção, restrinja para seu IP específico
  }

  # Regra de entrada - HTTP (porta 80)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de entrada - HTTPS (porta 443)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída - Permite todo tráfego de saída
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 significa todos os protocolos
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "sg-${var.instance_name}"
    }
  )
}
```

**B) Depois, criar a instância EC2 vinculando o Security Group:**

```terraform
# Instância EC2
resource "aws_instance" "main" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2.id]  # ← Vincula o Security Group
  associate_public_ip_address = true
  monitoring                  = var.monitoring

  tags = merge(
    var.tags,
    {
      Name        = var.instance_name
      Environment = var.environment
    }
  )
}
```

**Importante:**
- O Security Group **DEVE** ser criado antes da instância EC2
- A propriedade `vpc_security_group_ids` vincula o Security Group à instância
- Sem Security Group configurado, você NÃO conseguirá acessar a EC2 via SSH

Criar `modules/EC2/variables.tf` com as variáveis `vpc_id`, `instance_name`, `instance_type`, `ami_id`, `key_name`, `subnet_id`, `monitoring`, `environment` e `tags`.

Criar `modules/EC2/outputs.tf` com os outputs da instância.

### **5. Configurar Arquivo Principal**

Criar `main.tf` na raiz:
```terraform
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

module "ec2" {
  source = "./modules/EC2"

  instance_name = "app-server-${var.environment}"
  instance_type = var.ec2_instance_type
  ami_id        = var.ec2_ami_id
  key_name      = var.ec2_key_name
  monitoring    = var.ec2_monitoring
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  environment   = var.environment

  tags = merge(
    var.project_tags,
    {
      Name        = "app-server-${var.environment}"
      Environment = var.environment
    }
  )
}
```

### **6. Configurar Provider**

Criar `provider.tf`:
```terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }

  backend "s3" {
    bucket  = "course-infra-state-bucket-tf"
    region  = "us-east-1"
    key     = "terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

### **7. Definir Variáveis**

Criar `variables.tf` com todas as variáveis necessárias (environment, aws_profile, vpc_cidr, etc.)

### **8. Configurar Valores por Ambiente**

Criar `terraform.dev.tfvars`:
```terraform
environment  = "dev"
aws_profile  = "ericles-dev"
aws_region   = "us-east-1"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets    = ["10.0.10.0/24", "10.0.11.0/24"]
enable_nat_gateway = true
enable_vpn_gateway = false

ec2_instance_type = "t3.small"
ec2_ami_id        = "ami-0e2c8caa4b6378d8c"  # Ubuntu 22.04 LTS
ec2_key_name      = "challenge-iac-key"
ec2_monitoring    = false

project_tags = {
  Project = "Challenge-IAC"
  Owner   = "Ericles"
}
```

---

## 🎯 Como Usar

### **Inicializar o Terraform**

```bash
terraform init
```

Este comando:
- Baixa os providers necessários (AWS)
- Inicializa o backend (S3)
- Baixa módulos externos

### **Validar Configuração**

```bash
terraform validate
```

Verifica se a sintaxe está correta.

### **Formatar Código**

```bash
terraform fmt -recursive
```

Formata automaticamente os arquivos `.tf`.

### **Visualizar Mudanças (Plan)**

```bash
terraform plan -var-file="terraform.dev.tfvars"
```

Mostra o que será criado/modificado **sem aplicar** as mudanças.

### **Aplicar Mudanças (Apply)**

```bash
terraform apply -var-file="terraform.dev.tfvars"
```

Cria os recursos na AWS. Digite `yes` para confirmar.

### **Ver Outputs**

```bash
terraform output
```

Mostra informações importantes como IPs, IDs dos recursos, etc.

### **Destruir Recursos**

```bash
terraform destroy -var-file="terraform.dev.tfvars"
```

⚠️ **CUIDADO:** Remove TODOS os recursos criados. Digite `yes` para confirmar.

---

## 🏗️ Recursos Criados

Ao executar `terraform apply`, os seguintes recursos são criados na AWS:

### **VPC e Rede**
- 1 VPC (10.0.0.0/16)
- 2 Subnets Públicas (10.0.1.0/24, 10.0.2.0/24)
- 2 Subnets Privadas (10.0.10.0/24, 10.0.11.0/24)
- 1 Internet Gateway
- 2 NAT Gateways (um por AZ)
- Route Tables (públicas e privadas)

### **Compute**
- 1 Instância EC2 Ubuntu 22.04 LTS
  - Tipo: t3.small (2GB RAM, 2 vCPUs)
  - IP público atribuído automaticamente
  - Localizada em subnet pública
  - Security Group configurado (SSH, HTTP, HTTPS)

### **Custos Estimados (us-east-1)**
- EC2 t3.small: ~$15/mês
- NAT Gateway (2x): ~$64/mês
- **Total aproximado: $79/mês**

---

## 🌍 Ambientes

O projeto suporta múltiplos ambientes:

### **Desenvolvimento (dev)**
```bash
terraform apply -var-file="terraform.dev.tfvars"
```
- Recursos menores
- NAT Gateway habilitado
- Monitoramento desabilitado

### **Produção (prod)**
```bash
terraform apply -var-file="terraform.prod.tfvars"
```
- Recursos maiores
- Alta disponibilidade
- Monitoramento habilitado
- Proteção contra terminação

### **Staging**
```bash
terraform apply -var-file="terraform.staging.tfvars"
```
- Ambiente de testes pré-produção

---

## 🔐 Conectar à Instância EC2

Após o `terraform apply`, use o output para conectar via SSH:

```bash
# Ver o IP público
terraform output ec2_public_ip

# Conectar via SSH
ssh -i ~/.ssh/challenge-iac-key ubuntu@<IP_PUBLICO>
```

---

## 📚 Conceitos Importantes

### **Subnet Pública vs Privada**
- **Pública:** Tem rota para Internet Gateway, recursos podem ter IP público
- **Privada:** Sem rota direta para internet, usa NAT Gateway para saída

### **NAT Gateway**
- Permite que recursos em subnets privadas acessem a internet
- Necessário para atualizações de sistema, downloads, etc.
- Tem custo por hora + tráfego de dados

### **Modules**
- Agrupam recursos relacionados
- Permitem reutilização de código
- Facilitam manutenção e organização

### **AMI (Amazon Machine Image)**
- Imagem do sistema operacional para EC2
- Cada região tem AMIs diferentes
- Ubuntu 22.04 LTS: ami-0e2c8caa4b6378d8c (us-east-1)

### **Security Groups (Grupos de Segurança)**
- **O que é:** Firewall virtual que controla o tráfego de entrada e saída da instância EC2
- **Onde fica:** Anexado à instância EC2 (não à VPC)
- **Stateful:** Se você permite tráfego de entrada, a resposta de saída é automaticamente permitida

**Regras:**
- **Ingress (Entrada):** Controla quem pode ACESSAR sua instância
  - Exemplo: SSH (porta 22), HTTP (porta 80)
- **Egress (Saída):** Controla para onde sua instância pode SE CONECTAR
  - Exemplo: Acesso à internet, banco de dados

**No projeto:**
```terraform
# Security Group criado no módulo EC2
resource "aws_security_group" "ec2" {
  vpc_id = var.vpc_id
  
  # Permite SSH de qualquer IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Permite HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Permite todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Importante:**
- ⚠️ `0.0.0.0/0` significa "qualquer IP" - use apenas para HTTP/HTTPS
- 🔒 Para SSH em produção, restrinja para IPs específicos: `["SEU_IP/32"]`
- 📊 Um Security Group pode ser usado por várias instâncias

**Diferença: Security Group vs Network ACL**

| Security Group | Network ACL |
|---------------|-------------|
| Nível de instância | Nível de subnet |
| Stateful (retorno automático) | Stateless (precisa regra de retorno) |
| Só permite ALLOW | Permite ALLOW e DENY |
| Avalia todas as regras | Avalia regras em ordem numérica |

---

## 🔄 Próximos Passos

**Recursos a serem implementados:**

1. ✅ **Security Groups** - Implementado! Controla tráfego da EC2
2. **Load Balancer** - Distribuir tráfego entre múltiplas instâncias
3. **Auto Scaling** - Escalar automaticamente com base na demanda
4. **Bastion Host** - Acesso seguro a recursos privados
5. **RDS** - Banco de dados gerenciado
6. **S3 Buckets** - Armazenamento de objetos
7. **CloudWatch** - Monitoramento e logs

---

## 🛠️ Troubleshooting

### Vejo 2 VPCs no Console AWS - está correto?
**Sim! É normal ter 2 VPCs:**

1. **VPC Default** (criada automaticamente pela AWS)
   - CIDR geralmente: `172.31.0.0/16`
   - Criada quando você criou a conta AWS
   - Vem com subnets em todas as AZs da região
   - **Pode deletar?** Sim, mas NÃO é recomendado

2. **VPC do Projeto** (criada pelo Terraform)
   - Nome: `vpc-dev`
   - CIDR: `10.0.0.0/16`
   - Gerenciada pelo Terraform

**Como identificar a VPC do projeto:**
```bash
terraform output vpc_id
# Resultado: "vpc-0430229f21c7d13be" (exemplo)
```

Procure este ID no Console AWS para encontrar sua VPC!

---

### Erro: "InvalidAMIID.Malformed"
**Solução:** Verifique se o AMI ID é válido para a região configurada.

### Erro: "No value for required variable"
**Solução:** Verifique se todas as variáveis estão definidas no arquivo `.tfvars`.

### Erro: "locked provider version"
**Solução:** Execute `terraform init -upgrade`.

### EC2 sem IP público

### Não consigo conectar via SSH na EC2
**Possíveis causas:**
1. **Security Group não configurado:** Verifique se a porta 22 está aberta
2. **Chave SSH incorreta:** Confirme que está usando a chave certa
3. **IP público não atribuído:** Verifique se `associate_public_ip_address = true`

**Solução:**
```bash
# Ver o IP público
terraform output ec2_public_ip

# Verificar Security Group no Console AWS
# EC2 → Instância → Aba Security → Inbound rules → deve ter porta 22

# Testar conexão
ssh -i ~/.ssh/challenge-iac-key ubuntu@<IP_PUBLICO>
```
**Solução:** Adicione `associate_public_ip_address = true` no recurso EC2.

---

## 📖 Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

---

## 👤 Autor

**Ericles Miller**

Projeto desenvolvido como parte do desafio de Infraestrutura como Código (IaC).

---

## 📄 Licença

Este projeto é apenas para fins educacionais.
![1769099923501](image/README/1769099923501.png)![1769099934426](image/README/1769099934426.png)![1769099943289](image/README/1769099943289.png)![1769099972574](image/README/1769099972574.png)