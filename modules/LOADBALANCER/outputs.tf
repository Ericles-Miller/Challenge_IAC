# ==================================================
# OUTPUTS DO MÓDULO LOAD BALANCER
# ==================================================

# DNS do Load Balancer (URL para acessar a aplicação)
output "lb_dns_name" {
  description = "DNS público do Load Balancer"
  value       = aws_lb.main.dns_name
}

# ARN do Load Balancer
output "lb_arn" {
  description = "ARN do Load Balancer"
  value       = aws_lb.main.arn
}

# ID do Security Group do Load Balancer
output "lb_security_group_id" {
  description = "ID do Security Group do Load Balancer"
  value       = aws_security_group.lb_sg.id
}

# ARN do Target Group
output "target_group_arn" {
  description = "ARN do Target Group"
  value       = aws_lb_target_group.main.arn
}

# Zone ID (para Route 53 se necessário)
output "lb_zone_id" {
  description = "Zone ID do Load Balancer"
  value       = aws_lb.main.zone_id
}
