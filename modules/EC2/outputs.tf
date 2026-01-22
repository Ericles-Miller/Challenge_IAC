# ==================================================
# OUTPUTS DO MÓDULO EC2
# ==================================================

output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.main.id
}

output "public_ip" {
  description = "IP público da instância"
  value       = aws_instance.main.public_ip
}

output "private_ip" {
  description = "IP privado da instância"
  value       = aws_instance.main.private_ip
}

output "public_dns" {
  description = "DNS público da instância"
  value       = aws_instance.main.public_dns
}

output "availability_zone" {
  description = "Availability Zone da instância"
  value       = aws_instance.main.availability_zone
}
output "security_group_id" {
  description = "ID do Security Group da EC2"
  value       = aws_security_group.ec2.id
}