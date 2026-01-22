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