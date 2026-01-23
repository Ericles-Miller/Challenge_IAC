# ==================================================
# IAM ROLE - Permite que EC2 assuma permissões
# ==================================================
resource "aws_iam_role" "ec2_role" {
  name = var.role_name

  # Política de confiança - Permite que EC2 assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = var.role_name
      Environment = var.environment
    }
  )
}

# ==================================================
# INSTANCE PROFILE - Liga a IAM Role à EC2
# ==================================================
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.role_name}-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(
    var.tags,
    {
      Name        = "${var.role_name}-profile"
      Environment = var.environment
    }
  )
}

# ==================================================
# POLICY 1: CloudWatch Logs
# ==================================================
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.role_name}-cloudwatch-logs"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ==================================================
# POLICY 2: SSM Session Manager
# ==================================================
resource "aws_iam_role_policy" "ssm_session_manager" {
  name = "${var.role_name}-ssm"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetEncryptionConfiguration"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==================================================
# POLICY 3: S3 Access (Opcional)
# ==================================================
resource "aws_iam_role_policy" "s3_access" {
  count = var.enable_s3_access && length(var.s3_bucket_arns) > 0 ? 1 : 0
  
  name = "${var.role_name}-s3-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [for arn in var.s3_bucket_arns : "${arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

# ==================================================
# POLICY 4: CloudWatch Metrics (Monitoring)
# ==================================================
resource "aws_iam_role_policy" "cloudwatch_metrics" {
  name = "${var.role_name}-cloudwatch-metrics"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}
