resource "aws_security_group" "lb_sg" {
  name        = "${var.lb_name}-sg"
  description = "Security Group for Application Load Balancer"
  vpc_id      = var.vpc_id  # ✅ Corrigido: vpc_id

  # regras de entrada: 
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

  # Regra de saída: Permite enviar para qualquer destino
  # A segurança está garantida pelo Security Group da EC2 (que só aceita do LB)
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
# Agrupa as instâncias EC2 que receberão tráfego do Load Balancer
resource "aws_lb_target_group" "main" {
  name     = "${var.lb_name}-tg"
  port     = 80                    # Porta que a aplicação roda na EC2
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health Check - Verifica se a EC2 está saudável
  health_check {
    enabled             = true
    healthy_threshold   = 2        # Quantas verificações OK para considerar saudável
    unhealthy_threshold = 2        # Quantas falhas para considerar não-saudável
    timeout             = 5        # Timeout da verificação (segundos)
    interval            = 30       # Intervalo entre verificações (segundos)
    path                = "/"      # Caminho para testar (ex: /health)
    matcher             = "200"    # Código HTTP esperado
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
  internal           = false                           # false = público (acessível da internet)
  load_balancer_type = "application"                  # ALB (não NLB ou CLB)
  security_groups    = [aws_security_group.lb_sg.id]  # Security Group criado acima
  subnets            = var.public_subnets             # Subnets públicas (mínimo 2)

  enable_deletion_protection = false  # true em produção (evita deletar acidentalmente)

  tags = {
    Name        = var.lb_name
    Environment = var.environment
  }
}

# ==================================================
# PASSO 4: LISTENER
# ==================================================
# Escuta requisições HTTP na porta 80 e encaminha para o Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn  # ARN do Load Balancer criado acima
  port              = "80"             # Porta que o LB escuta
  protocol          = "HTTP"

  # Ação padrão: Encaminhar para o Target Group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ==================================================
# PASSO 5: TARGET GROUP ATTACHMENT
# ==================================================
# Registra a instância EC2 no Target Group
resource "aws_lb_target_group_attachment" "ec2" {
  target_group_arn = aws_lb_target_group.main.arn  # Target Group criado acima
  target_id        = var.ec2_instance_id           # ID da instância EC2
  port             = 80                            # Porta da aplicação na EC2
}