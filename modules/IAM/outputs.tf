output "role_arn" {
  description = "ARN da IAM Role"
  value       = aws_iam_role.ec2_role.arn
}

output "role_name" {
  description = "Nome da IAM Role"
  value       = aws_iam_role.ec2_role.name
}

output "instance_profile_arn" {
  description = "ARN do Instance Profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "instance_profile_name" {
  description = "Nome do Instance Profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}
