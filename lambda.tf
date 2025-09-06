# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "website-monitoring-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"

  depends_on = [aws_iam_role.lambda_role]
}

resource "aws_iam_role_policy_attachment" "lambda_kinesis_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"

  depends_on = [aws_iam_role.lambda_role]
}

resource "aws_iam_role_policy_attachment" "lambda_sns_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"

  depends_on = [aws_iam_role.lambda_role]
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_full_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"

  depends_on = [aws_iam_role.lambda_role]
}

# Attach Basic Lambda Execution Role for CloudWatch Logs
resource "aws_iam_policy_attachment" "lambda_basic_execution" {
  name       = "lambda_basic_execution"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Security group for Lambda in VPC"
  vpc_id      = aws_vpc.aurora_vpc.id  # Replace with your VPC ID

  # Allow outbound traffic (required for database connection)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "aurora_allow_lambda" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aurora_sg.id  # Aurora's security group
  source_security_group_id = aws_security_group.lambda_sg.id  # Lambda's security group
}

# Create Lambda Function
resource "aws_lambda_function" "website_monitoring_lambda" {
  function_name = "website-monitoring-lambda"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  memory_size   = 1280
  ephemeral_storage {
    size = 512
  }
  timeout       = 300  # 5 minutes

  filename         = "lambda.zip"  # Ensure lambda.zip exists in the same directory when running Terraform
  
  # Attach Lambda to the VPC
  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      RDS_HOST      = aws_rds_cluster.aurora_cluster.endpoint  # Dynamically fetch RDS cluster endpoint
      RDS_USER      = "admin"
      RDS_PASSWORD  = "securepassword123"  # Consider using AWS Secrets Manager
      RDS_DB_NAME   = "logs"
      SNS_TOPIC_ARN = aws_sns_topic.website_monitoring_alert.arn  # Dynamically fetch SNS Topic ARN
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_dynamodb_policy,
    aws_iam_role_policy_attachment.lambda_kinesis_policy,
    aws_iam_role_policy_attachment.lambda_sns_policy,
    aws_iam_policy_attachment.lambda_basic_execution
  ]
}
