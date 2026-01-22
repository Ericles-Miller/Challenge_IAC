# Recurso EC2 - Instância Linux
resource "aws_instance" "main" {
  ami           = var.ami_id              # Imagem do Linux
  instance_type = var.instance_type       # t3.small = 2GB RAM
  key_name      = var.key_name            # Chave SSH
  subnet_id     = var.subnet_id           # Subnet da VPC
  
  # Habilita IP público (necessário para acesso da internet)
  associate_public_ip_address = true
  
  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}