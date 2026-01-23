# Implementação de Segurança - EBS Encryption e IAM Role

Este documento explica as implementações de segurança adicionadas ao projeto: **Criptografia EBS** e **IAM Role**.

---

## 📚 Índice

1. [Criptografia EBS](#criptografia-ebs)
2. [IAM Role](#iam-role)
3. [Como Testar](#como-testar)
4. [Resumo de Arquivos Modificados](#resumo-de-arquivos-modificados)

---

## 🔐 Criptografia EBS

### O que é EBS?

**EBS (Elastic Block Store)** é o disco virtual da instância EC2, onde ficam:
- Sistema operacional (Ubuntu)
- Aplicação instalada
- Logs e arquivos
- Configurações

### Por que criptografar?

| Sem Criptografia | Com Criptografia |
|------------------|------------------|
| ❌ Dados legíveis se disco for acessado fisicamente | ✅ Dados ilegíveis sem chave KMS |
| ❌ Snapshots em texto claro | ✅ Snapshots automaticamente criptografados |
| ❌ Risco de vazamento de dados | ✅ Conformidade com LGPD, PCI-DSS |

### Como funciona?

```
Aplicação escreve dados
    ↓
AWS KMS automaticamente criptografa
    ↓
Dados armazenados criptografados no EBS
    ↓
Aplicação lê dados
    ↓
AWS automaticamente descriptografa
    ↓
Aplicação recebe dados (transparente!)
```

**Importante:** Você NÃO percebe a criptografia! Funciona normalmente ao acessar via SSH.

---

### Implementação

#### 1. Variáveis adicionadas

**Arquivo:** `modules/EC2/variables.tf`

```hcl
variable "enable_ebs_encryption" {
  type        = bool
  description = "Habilitar criptografia nos volumes EBS"
  default     = true
}

variable "ebs_volume_size" {
  type        = number
  description = "Tamanho do volume raiz em GB"
  default     = 30
}

variable "ebs_volume_type" {
  type        = string
  description = "Tipo do volume EBS (gp3, gp2, io1, io2)"
  default     = "gp3"
}
```

**O que cada uma faz:**
- `enable_ebs_encryption`: Liga/desliga criptografia (sempre `true` em prod)
- `ebs_volume_size`: Tamanho do disco (8 GB dev, 10 GB prod)
- `ebs_volume_type`: Tipo do SSD (gp3 = mais moderno e barato)

---

#### 2. Configuração na instância EC2

**Arquivo:** `modules/EC2/main.tf`

```hcl
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id
  
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  # ✅ CRIPTOGRAFIA EBS
  root_block_device {
    volume_size           = var.ebs_volume_size       # Tamanho (8-10 GB)
    volume_type           = var.ebs_volume_type       # Tipo: gp3
    encrypted             = var.enable_ebs_encryption # Criptografia habilitada
    delete_on_termination = true                      # Deleta ao destruir EC2
    
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
```

**O que mudou:**
- Adicionado bloco `root_block_device`
- `encrypted = true` ativa a criptografia
- AWS usa chave KMS padrão automaticamente

---

#### 3. Configuração por ambiente

**Arquivo:** `terraform.dev.tfvars`
```hcl
enable_ebs_encryption = true
ebs_volume_size       = 8     # 8 GB suficiente para API
ebs_volume_type       = "gp3"
```

**Arquivo:** `terraform.prod.tfvars`
```hcl
enable_ebs_encryption = true
ebs_volume_size       = 10    # 10 GB com margem extra
ebs_volume_type       = "gp3"
```

**Por que 8-10 GB?**
```
Ubuntu 22.04:           ~2-3 GB
Node.js/Python/Java:    ~500 MB - 1 GB
API:                    ~200-500 MB
Dependências:           ~500 MB - 1 GB
Logs:                   ~500 MB - 1 GB
Espaço livre:           ~1-2 GB
──────────────────────────────
TOTAL:                  ~6-10 GB
```

Como dados estão em RDS/S3, não precisa de muito espaço!

---

### Custo

| Configuração | Preço/mês | Observação |
|--------------|-----------|------------|
| gp3 8 GB (dev) | $0.64 | Economia vs 30 GB: $1.76 |
| gp3 10 GB (prod) | $0.80 | Economia vs 50 GB: $3.20 |
| **Criptografia** | **$0.00** | GRÁTIS! |

**Economia total:** ~$4.96/mês = ~$60/ano

---

## 🔑 IAM Role

### O que é IAM Role?

**IAM Role** é um conjunto de permissões que a EC2 pode usar para acessar outros serviços AWS **sem precisar de credenciais hardcoded**.

### Por que usar?

| Sem IAM Role | Com IAM Role |
|--------------|--------------|
| ❌ Credenciais no código | ✅ Sem credenciais no código |
| ❌ AWS_ACCESS_KEY exposta | ✅ Credenciais temporárias automáticas |
| ❌ Risco de vazamento | ✅ Seguro e gerenciável |
| ❌ Difícil rotacionar | ✅ Rotação automática |

---

### Estrutura criada

```
modules/IAM/
├── main.tf         # IAM Role + Policies
├── variables.tf    # Configurações
└── outputs.tf      # ARNs e nomes
```

---

### Políticas incluídas

#### 1. CloudWatch Logs ✅

**Objetivo:** Enviar logs do sistema para CloudWatch

**Permissões:**
```json
{
  "Action": [
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "logs:DescribeLogStreams"
  ]
}
```

**Uso prático:**
```bash
# Na EC2, sem credenciais:
aws logs create-log-stream --log-group-name /api/logs --log-stream-name app-logs

# Ou via SDK (Python):
import boto3
logs = boto3.client('logs')
logs.put_log_events(
    logGroupName='/api/logs',
    logStreamName='app',
    logEvents=[{'message': 'API iniciada', 'timestamp': 1234567890000}]
)
```

---

#### 2. SSM Session Manager ✅

**Objetivo:** Acesso SSH sem chave pública (mais seguro)

**Permissões:**
```json
{
  "Action": [
    "ssm:UpdateInstanceInformation",
    "ssmmessages:CreateControlChannel",
    "ssmmessages:CreateDataChannel",
    "ssmmessages:OpenControlChannel",
    "ssmmessages:OpenDataChannel"
  ]
}
```

**Uso prático:**
```bash
# Via AWS Console:
EC2 → Instâncias → Selecionar EC2 → Connect → Session Manager → Connect

# Via CLI:
aws ssm start-session --target i-1234567890abcdef0
```

**Vantagens:**
- ✅ Não precisa de chave SSH
- ✅ Não precisa abrir porta 22
- ✅ Logs de acesso automáticos
- ✅ Mais seguro

---

#### 3. CloudWatch Metrics ✅

**Objetivo:** Enviar métricas customizadas

**Permissões:**
```json
{
  "Action": [
    "cloudwatch:PutMetricData",
    "ec2:DescribeVolumes",
    "ec2:DescribeTags"
  ]
}
```

**Uso prático:**
```bash
# Enviar métrica customizada
aws cloudwatch put-metric-data \
  --namespace "MinhAPI" \
  --metric-name "RequestsPerSecond" \
  --value 150 \
  --unit Count
```

---

#### 4. S3 Access 🔵 (Opcional - Desabilitado)

**Objetivo:** Ler/escrever arquivos no S3

**Status:** Desabilitado por padrão

**Para habilitar:**

1. Editar `terraform.dev.tfvars`:
```hcl
enable_s3_access = true
s3_bucket_arns   = ["arn:aws:s3:::meu-bucket-dev"]
```

2. Aplicar:
```bash
terraform apply -var-file="terraform.dev.tfvars"
```

**Uso prático:**
```python
import boto3

s3 = boto3.client('s3')

# Upload
s3.upload_file('arquivo.txt', 'meu-bucket-dev', 'arquivo.txt')

# Download
s3.download_file('meu-bucket-dev', 'arquivo.txt', 'local.txt')
```

---

### Implementação

#### 1. Criar módulo IAM

**Arquivo:** `modules/IAM/main.tf`

```hcl
# IAM Role
resource "aws_iam_role" "ec2_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Instance Profile (liga Role à EC2)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.role_name}-profile"
  role = aws_iam_role.ec2_role.name
}

# Políticas (CloudWatch, SSM, S3)
resource "aws_iam_role_policy" "cloudwatch_logs" { ... }
resource "aws_iam_role_policy" "ssm_session_manager" { ... }
resource "aws_iam_role_policy" "cloudwatch_metrics" { ... }
resource "aws_iam_role_policy" "s3_access" { ... }
```

---

#### 2. Integrar com EC2

**Arquivo:** `modules/EC2/main.tf`

```hcl
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  # ✅ ASSOCIAR IAM ROLE
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  # ... resto da configuração
}
```

---

#### 3. Configurar no main.tf (raiz)

**Arquivo:** `main.tf`

```hcl
# Módulo IAM (criado ANTES da EC2)
module "iam" {
  count  = var.enable_iam_role ? 1 : 0
  source = "./modules/IAM"

  role_name        = "ec2-role-${var.environment}"
  environment      = var.environment
  enable_s3_access = var.enable_s3_access
  s3_bucket_arns   = var.s3_bucket_arns
}

# Módulo EC2 (recebe IAM Instance Profile)
module "ec2" {
  source = "./modules/EC2"
  
  # ... outras configurações
  
  # Passar IAM Instance Profile
  iam_instance_profile = var.enable_iam_role ? module.iam[0].instance_profile_name : ""
}
```

---

#### 4. Configuração nos tfvars

**Arquivo:** `terraform.dev.tfvars`
```hcl
enable_iam_role  = true   # Habilitar IAM Role
enable_s3_access = false  # S3 desabilitado (altere se necessário)
s3_bucket_arns   = []
```

**Arquivo:** `terraform.prod.tfvars`
```hcl
enable_iam_role  = true
enable_s3_access = false
s3_bucket_arns   = []
```

---

## 🧪 Como Testar

### Teste 1: Verificar criptografia EBS

```bash
# Após terraform apply
aws ec2 describe-volumes \
  --filters "Name=attachment.instance-id,Values=$(terraform output -raw ec2_instance_id)" \
  --query 'Volumes[0].Encrypted'

# Saída esperada: true
```

---

### Teste 2: Verificar IAM Role

```bash
# Ver IAM Role associada
terraform output iam_role_name

# Saída: ec2-role-dev
```

---

### Teste 3: Testar CloudWatch Logs

```bash
# SSH na EC2
ssh -i ~/.ssh/challenge-iac-key.pem ubuntu@$(terraform output -raw ec2_public_ip)

# Dentro da EC2, criar log group (sem credenciais!)
aws logs create-log-group --log-group-name /test/logs

# Verificar
aws logs describe-log-groups --log-group-name-prefix /test
```

---

### Teste 4: Testar Session Manager

```bash
# No seu terminal local
aws ssm start-session --target $(terraform output -raw ec2_instance_id)

# Deve conectar sem precisar de chave SSH!
```

---

### Teste 5: Verificar S3 (se habilitado)

```bash
# Dentro da EC2
aws s3 ls s3://meu-bucket-dev/

# Deve listar arquivos sem erro de permissão
```

---

## 📊 Resumo de Arquivos Modificados

### Novos arquivos criados:

```
modules/IAM/
├── main.tf        ✅ IAM Role + 4 Policies
├── variables.tf   ✅ Configurações
└── outputs.tf     ✅ Outputs
```

### Arquivos modificados:

| Arquivo | O que foi adicionado |
|---------|---------------------|
| `modules/EC2/variables.tf` | Variáveis de criptografia EBS + IAM |
| `modules/EC2/main.tf` | Bloco `root_block_device` + `iam_instance_profile` |
| `variables.tf` (raiz) | Variáveis EBS e IAM |
| `main.tf` (raiz) | Módulo IAM + integração com EC2 |
| `outputs.tf` (raiz) | Outputs IAM Role |
| `terraform.dev.tfvars` | Configurações EBS e IAM |
| `terraform.prod.tfvars` | Configurações EBS e IAM |

---

## 🎯 Benefícios Implementados

### Segurança:
- ✅ Dados criptografados em repouso (EBS)
- ✅ Sem credenciais hardcoded (IAM Role)
- ✅ Acesso seguro via Session Manager
- ✅ Logs centralizados em CloudWatch

### Conformidade:
- ✅ LGPD (criptografia de dados)
- ✅ PCI-DSS (proteção de dados sensíveis)
- ✅ ISO 27001 (controle de acesso)

### Operacional:
- ✅ Zero custo adicional (criptografia grátis)
- ✅ Transparente para aplicação
- ✅ Fácil gerenciamento de permissões
- ✅ Logs e auditoria automáticos

---

## 📝 Comandos para Deploy

```bash
# 1. Inicializar novo módulo
terraform init

# 2. Validar configuração
terraform validate

# 3. Ver mudanças
terraform plan -var-file="terraform.dev.tfvars"

# 4. Aplicar
terraform apply -var-file="terraform.dev.tfvars"
```

---

## 🔄 Próximos Passos

Agora que segurança está implementada, falta apenas:
- ⏭️ **Auto Scaling Group** - Para alta disponibilidade

---

**Última atualização:** 23 de janeiro de 2026
