variable "lb_name" {
  type        = string
  description = "Nome do Load Balancer"
}

variable "vpc_id" {
  type        = string
  description = "ID da VPC onde o Load Balancer será criado"
}

variable "public_subnets" {
  type        = list(string)
  description = "Lista de IDs das subnets públicas para o Load Balancer"
}

variable "ec2_instance_id" {
  type        = string
  description = "ID da instância EC2 para registrar no Target Group"
}

variable "environment" {
  type        = string
  description = "Ambiente (dev, prod)"
} 