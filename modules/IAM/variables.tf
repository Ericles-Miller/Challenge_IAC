variable "role_name" {
  type        = string
  description = "Nome da IAM Role para a EC2"
}

variable "environment" {
  type        = string
  description = "Ambiente (dev, prod)"
}

variable "enable_s3_access" {
  type        = bool
  description = "Habilitar acesso ao S3"
  default     = false
}

variable "s3_bucket_arns" {
  type        = list(string)
  description = "Lista de ARNs dos buckets S3 que a EC2 pode acessar"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionais"
  default     = {}
}
