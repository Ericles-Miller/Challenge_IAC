

Este documento descreve **passo a passo** tudo que foi implementado no projeto, desde a criação da infraestrutura até o deploy da API NestJS.

---

## 📋 Sumário

1. [Visão Geral](#visão-geral)
2. [Infraestrutura Criada](#infraestrutura-criada)
3. [Pré-requisitos](#pré-requisitos)
4. [Passo 1: Criar Infraestrutura com Terraform](#passo-1-criar-infraestrutura-com-terraform)
5. [Passo 2: Configurar Acesso SSH](#passo-2-configurar-acesso-ssh)
6. [Passo 3: Instalar e Configurar Nginx](#passo-3-instalar-e-configurar-nginx)
7. [Passo 4: Deploy da API NestJS](#passo-4-deploy-da-api-nestjs)
8. [Passo 5: Configurar PM2 (Persistência)](#passo-5-configurar-pm2-persistência)
9. [Verificação e Testes](#verificação-e-testes)
10. [Destruir Infraestrutura](#destruir-infraestrutura)
11. [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

Este projeto implementa uma infraestrutura completa na AWS usando Terraform, com:

- **VPC** personalizada com subnets públicas e privadas
- **EC2** para hospedar a aplicação
- **Application Load Balancer** para distribuição de tráfego
- **Nginx** como reverse proxy
- **API NestJS** rodando na porta 3000

### Fluxo de Tráfego

```
Internet
    ↓
Application Load Balancer (porta 80)
    ↓
Nginx (porta 80)
    ↓
API NestJS (porta 3000)
    ↓
Response: "Hello World"
```

---

## 🏗️ Infraestrutura Criada

### Recursos AWS

| Recurso | Quantidade | Descrição |
|---------|-----------|-----------|
| VPC | 1 | CIDR: 10.0.0.0/16 |
| Subnets Públicas | 2 | us-east-1a, us-east-1b |
| Subnets Privadas | 2 | us-east-1a, us-east-1b |
| Internet Gateway | 1 | Acesso à internet |
| NAT Gateway | 1 | Para subnets privadas |
| Route Tables | 2 | Pública e privada |
| Security Groups | 3 | ALB, EC2, e VPC default |
| Application Load Balancer | 1 | Distribuição de tráfego |
| Target Group | 1 | Porta 80, health checks |
| EC2 Instance | 1 | t3.small, Ubuntu 22.04 |
| IAM Role | 1 | Permissões para EC2 |

### Security Groups

**Load Balancer SG:**
- Ingress: 0.0.0.0/0:80 (HTTP)
- Ingress: 0.0.0.0/0:443 (HTTPS)
- Egress: 0.0.0.0/0 (All)

**EC2 SG:**
- Ingress: LB-SG:80 (HTTP apenas do Load Balancer)
- Ingress: LB-SG:443 (HTTPS apenas do Load Balancer)
- Ingress: SEU-IP:22 (SSH - configurável)
- Egress: 0.0.0.0/0 (All)

---

## ✅ Pré-requisitos

### Ferramentas Necessárias

- **Terraform** >= 1.0
- **AWS CLI** configurado
- **SSH Key Pair** criado na AWS
- **Git** (opcional)

### Configuração AWS CLI

```bash
# Configurar profile dev
aws configure --profile ericles-dev
# AWS Access Key ID: [sua_key]
# AWS Secret Access Key: [seu_secret]
# Default region: us-east-1
# Default output format: json
```

### Criar SSH Key Pair

```bash
# Criar key pair na AWS
aws ec2 create-key-pair \
  --key-name challenge-iac-key \
  --profile ericles-dev \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/challenge-iac-key

# Ajustar permissões
chmod 400 ~/.ssh/challenge-iac-key
```

---

## 🚀 Passo 1: Criar Infraestrutura com Terraform

### 1.1 Clonar o Repositório

```bash
git clone https://github.com/Ericles-Miller/Challenge_IAC.git
cd Challenge_IAC
```

### 1.2 Inicializar Terraform

```bash
terraform init
```

Este comando:
- Baixa o provider AWS
- Inicializa os módulos
- Configura o backend

### 1.3 Validar Configuração

```bash
terraform validate
```

### 1.4 Planejar Deploy

```bash
terraform plan -var-file="terraform.dev.tfvars"
```

Revise os recursos que serão criados.

### 1.5 Aplicar Infraestrutura

```bash
terraform apply -var-file="terraform.dev.tfvars"
```

Digite `yes` quando solicitado.

**Tempo estimado:** 3-5 minutos

### 1.6 Verificar Outputs

```bash
terraform output
```

Você verá:
```
ec2_public_ip = "98.83.158.196"
lb_dns_name = "alb-dev-13897310.us-east-1.elb.amazonaws.com"
lb_url = "http://alb-dev-13897310.us-east-1.elb.amazonaws.com"
ssh_connection = "ssh -i ~/.ssh/challenge-iac-key ubuntu@98.83.158.196"
```

---

## 🔐 Passo 2: Configurar Acesso SSH

### 2.1 Obter Seu IP Público

```bash
curl -s ifconfig.me
```

Exemplo: `177.10.146.136`

### 2.2 Adicionar Regra SSH no Security Group

**Opção A: Via AWS CLI (Rápido)**

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $(terraform output -raw ec2_security_group_id) \
  --protocol tcp \
  --port 22 \
  --cidr $(curl -s ifconfig.me)/32 \
  --profile ericles-dev \
  --region us-east-1
```

**Opção B: Via Console AWS**

1. AWS Console → EC2 → Security Groups
2. Selecionar `app-server-dev-sg`
3. Edit Inbound Rules → Add Rule
4. Type: SSH, Port: 22, Source: My IP
5. Save rules

### 2.3 Testar Conexão SSH

```bash
ssh -i ~/.ssh/challenge-iac-key ubuntu@98.83.158.196
```

Se conectou com sucesso, você está dentro da EC2! ✅

---

## 🔧 Passo 3: Instalar e Configurar Nginx

### 3.1 Atualizar Sistema e Instalar Nginx

**Na EC2:**

```bash
sudo apt update
sudo apt install -y nginx
```

### 3.2 Criar Configuração de Reverse Proxy

**Criar arquivo de configuração:**

```bash
sudo tee /etc/nginx/sites-available/api > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

**O que essa configuração faz:**
- Escuta na porta 80
- Encaminha todas as requisições para `localhost:3000`
- Adiciona headers HTTP necessários
- Suporta WebSocket (upgrade connection)

### 3.3 Ativar Configuração

```bash
# Criar link simbólico
sudo ln -s /etc/nginx/sites-available/api /etc/nginx/sites-enabled/api

# Remover configuração padrão
sudo rm -f /etc/nginx/sites-enabled/default

# Testar configuração
sudo nginx -t

# Recarregar Nginx
sudo systemctl reload nginx

# Verificar status
sudo systemctl status nginx
```

Deve aparecer: `active (running)` ✅

### 3.4 Testar Nginx

```bash
curl localhost
```

**Resultado esperado:** `502 Bad Gateway`

Isso é **normal** porque ainda não há aplicação rodando na porta 3000.

---

## 🐱 Passo 4: Deploy da API NestJS

### 4.1 Instalar Node.js

**Na EC2:**

```bash
# Adicionar repositório NodeSource (Node.js 20)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Instalar Node.js e npm
sudo apt install -y nodejs

# Verificar instalação
node --version  # Deve mostrar v20.x.x
npm --version   # Deve mostrar 10.x.x
```

### 4.2 Deploy da Aplicação

**Opção A: Clonar do Git (Recomendado)**

```bash
# Clonar repositório
git clone https://github.com/seu-usuario/sua-api-nestjs.git

# Entrar no diretório
cd sua-api-nestjs

# Instalar dependências
npm install

# Configurar porta (se necessário)
# Editar .env ou variável de ambiente PORT=3000

# Build (se TypeScript)
npm run build

# Rodar em produção
npm run start:prod
```

**Opção B: Criar API Simples para Teste**

```bash
# Criar arquivo app.js
cat > app.js <<'EOF'
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: 'Hello World - Challenge IAC!',
    timestamp: new Date().toISOString(),
    path: req.url,
    hostname: require('os').hostname()
  }));
});

server.listen(3000, () => {
  console.log('API rodando na porta 3000');
});
EOF

# Rodar aplicação
node app.js
```

Deve aparecer: `API rodando na porta 3000` ✅

### 4.3 Testar Localmente na EC2

**Abra outro terminal SSH:**

```bash
ssh -i ~/.ssh/challenge-iac-key ubuntu@98.83.158.196
```

**Teste:**

```bash
curl localhost
```

Deve retornar JSON: `{"message": "Hello World - Challenge IAC!", ...}` ✅

---

## 🔄 Passo 5: Configurar PM2 (Persistência)

Para manter a aplicação rodando permanentemente, mesmo após reiniciar a EC2:

### 5.1 Instalar PM2

**Na EC2:**

```bash
sudo npm install -g pm2
```

### 5.2 Rodar Aplicação com PM2

**Para API Node.js simples:**

```bash
pm2 start app.js --name "api-challenge"
```

**Para API NestJS:**

```bash
# No diretório do projeto
pm2 start npm --name "nestjs-api" -- run start:prod

# Ou se tiver dist/main.js
pm2 start dist/main.js --name "nestjs-api"
```

### 5.3 Configurar Auto-Start

```bash
# Configurar PM2 para iniciar no boot
pm2 startup

# Copiar e executar o comando que aparecer (sudo env PATH=...)

# Salvar lista de processos
pm2 save
```

### 5.4 Comandos Úteis PM2

```bash
# Ver processos
pm2 list

# Ver logs
pm2 logs

# Ver logs de um processo específico
pm2 logs api-challenge

# Reiniciar
pm2 restart api-challenge

# Parar
pm2 stop api-challenge

# Remover
pm2 delete api-challenge

# Monitoramento
pm2 monit
```

---

## ✅ Verificação e Testes

### 1. Verificar Health Checks

**Aguarde 30-60 segundos** para os health checks passarem.

**Verificar no Console AWS:**
1. EC2 → Target Groups
2. Selecionar `alb-dev-tg`
3. Aba **Targets**
4. Status deve estar: **Healthy** ✅

**Via CLI:**

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --profile ericles-dev \
  --region us-east-1
```

### 2. Testar Load Balancer

**Via terminal local:**

```bash
curl http://alb-dev-13897310.us-east-1.elb.amazonaws.com
```

**Via navegador:**

Abra: `http://alb-dev-13897310.us-east-1.elb.amazonaws.com`

Deve aparecer: `{"message": "Hello World - Challenge IAC!", ...}` ✅

### 3. Testar Múltiplas Requisições

```bash
# Fazer 10 requisições
for i in {1..10}; do
  curl http://alb-dev-13897310.us-east-1.elb.amazonaws.com
  echo ""
done
```

Todas devem retornar HTTP 200 com JSON.

---

## 🧹 Destruir Infraestrutura

Quando não estiver usando, destrua os recursos para evitar custos:

### Via Terraform

```bash
terraform destroy -var-file="terraform.dev.tfvars"
```

Digite `yes` quando solicitado.

**Isso remove:**
- ✅ Load Balancer (~$20/mês economizado)
- ✅ EC2 (~$15/mês economizado)
- ✅ NAT Gateway (~$32/mês economizado)
- ✅ VPC, subnets, IGW (sem custo)
- ✅ Security Groups (sem custo)

### Recriar Quando Precisar

```bash
terraform apply -var-file="terraform.dev.tfvars"
```

**Nota:** Você precisará reinstalar Nginx, Node.js e fazer deploy da API novamente.

---

## 🔧 Troubleshooting

### Problema 1: Não consigo conectar via SSH

**Sintoma:**
```
ssh: connect to host X.X.X.X port 22: Connection timed out
```

**Solução:**
```bash
# Adicionar seu IP no Security Group
aws ec2 authorize-security-group-ingress \
  --group-id $(terraform output -raw ec2_security_group_id) \
  --protocol tcp --port 22 \
  --cidr $(curl -s ifconfig.me)/32 \
  --profile ericles-dev
```

### Problema 2: Load Balancer retorna 502 Bad Gateway

**Possíveis causas:**
1. API não está rodando na porta 3000
2. Nginx não está configurado corretamente
3. Firewall bloqueando porta 3000

**Verificar:**
```bash
# Na EC2, verificar se API está rodando
curl localhost:3000

# Verificar Nginx
sudo nginx -t
sudo systemctl status nginx

# Ver logs do Nginx
sudo tail -f /var/log/nginx/error.log
```

### Problema 3: Load Balancer retorna 503 Service Unavailable

**Causa:** Health checks estão falhando.

**Verificar:**
```bash
# Ver status do Target Group
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --profile ericles-dev

# Na EC2, testar endpoint de health
curl localhost/
```

### Problema 4: Aplicação para quando fecho terminal SSH

**Causa:** Processo rodando em foreground.

**Solução:** Usar PM2 (ver Passo 5)

### Problema 5: Seu IP mudou e não consegue mais SSH

**Solução:**
```bash
# Obter novo IP
curl -s ifconfig.me

# Atualizar Security Group
aws ec2 authorize-security-group-ingress \
  --group-id $(terraform output -raw ec2_security_group_id) \
  --protocol tcp --port 22 \
  --cidr $(curl -s ifconfig.me)/32 \
  --profile ericles-dev

# Remover IP antigo (opcional)
aws ec2 revoke-security-group-ingress \
  --group-id $(terraform output -raw ec2_security_group_id) \
  --protocol tcp --port 22 \
  --cidr IP_ANTIGO/32 \
  --profile ericles-dev
```

---

## 📊 Custos Estimados

**Ambiente Dev (us-east-1):**

| Recurso | Custo/mês |
|---------|-----------|
| EC2 t3.small | ~$15 |
| Application Load Balancer | ~$20 |
| NAT Gateway | ~$32 |
| Data Transfer | Variável |
| EBS Storage (8GB) | ~$1 |
| **Total aproximado** | **~$68/mês** |

**Como economizar:**
- Destruir infraestrutura quando não usar (`terraform destroy`)
- Usar t3.micro no Free Tier (primeiro ano)
- Remover NAT Gateway se não usar subnets privadas

---

## 📚 Recursos Adicionais

### Comandos Úteis

```bash
# Ver todos os outputs do Terraform
terraform output

# Ver output específico
terraform output lb_dns_name

# Ver state
terraform show

# Listar recursos
terraform state list

# Refresh state
terraform refresh -var-file="terraform.dev.tfvars"

# Ver logs do Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Ver logs do PM2
pm2 logs --lines 100

# Monitorar recursos da EC2
htop
```

### Próximas Melhorias

- [ ] Adicionar HTTPS com AWS Certificate Manager
- [ ] Implementar Auto Scaling Group
- [ ] Adicionar RDS (PostgreSQL/MySQL)
- [ ] Configurar CloudWatch Alarms
- [ ] Implementar CI/CD com GitHub Actions
- [ ] Adicionar WAF para proteção
- [ ] Configurar backups automáticos
- [ ] Implementar logs centralizados (CloudWatch Logs)

---

## ✅ Checklist Final

- [ ] Infraestrutura criada via Terraform
- [ ] SSH configurado e funcionando
- [ ] Nginx instalado e configurado como reverse proxy
- [ ] Node.js instalado (versão 20+)
- [ ] API rodando na porta 3000
- [ ] PM2 configurado para persistência
- [ ] Health checks passando (Healthy)
- [ ] Load Balancer retornando resposta da API
- [ ] Documentação completa (este arquivo)
- [ ] Código commitado no Git
- [ ] README.md atualizado

---

**Última atualização:** 02 de fevereiro de 2026

**Autor:** Ericles Miller

**Repositório:** [Challenge_IAC](https://github.com/Ericles-Miller/Challenge_IAC)
