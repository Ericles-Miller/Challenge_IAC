variable "instance_name" {
  type        = string
  description = "Nome da instância EC2"
}

variable "instance_type" {
  type        = string
  description = "Tipo da instância (ex: t3.small para 2GB RAM)"
}

variable "ami_id" {
  type        = string
  description = "ID da imagem Linux (AMI)"
}

variable "key_name" {
  type        = string
  description = "Nome da chave SSH"
}

variable "subnet_id" {
  type        = string
  description = "ID da subnet"
}

variable "vpc_id" {
  type        = string
  description = "ID da VPC"
}

variable "lb_security_group_id" {
  type        = string
  description = "ID do Security Group do Load Balancer"
}

variable "ssh_allowed_ips" {
  type        = list(string)
  description = "Lista de IPs permitidos para SSH. Deixe vazio [] para gerenciar manualmente no console AWS"
  default     = []  # Lista vazia - você gerencia pelo console
}

variable "monitoring" {
  type        = bool
  description = "Habilitar monitoramento detalhado"
  default     = false
}

variable "environment" {
  type        = string
  description = "Ambiente (dev, prod)"
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionais"
  default     = {}
}

# ==================================================
# VARIÁVEIS DE CRIPTOGRAFIA EBS
# ==================================================

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