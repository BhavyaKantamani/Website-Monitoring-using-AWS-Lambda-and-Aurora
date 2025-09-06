# ----------------------------
# S3 Bucket for Logs
# ----------------------------
resource "aws_s3_bucket" "website_monitor_logs" {
  bucket = "website-monitor-drp-logs-2"

  tags = {
    Name = "Website Monitor Logs"
  }
}

# S3 Bucket Folder (Processed)
resource "aws_s3_object" "processed_folder" {
  bucket = aws_s3_bucket.website_monitor_logs.bucket
  key    = "processed/" # Creates a folder
}

# ----------------------------
# IAM Role for Firehose
# ----------------------------
resource "aws_iam_role" "firehose_role" {
  name = "FirehoseDeliveryRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach CloudWatch Full Access Policy
resource "aws_iam_policy_attachment" "firehose_cloudwatch_full_access" {
  name       = "ec2-cloudwatch-full-access-attachment"
  roles      = [aws_iam_role.firehose_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_policy_attachment" "firehose_lambda_full_access" {
  name       = "ec2-cloudwatch-full-access-attachment"
  roles      = [aws_iam_role.firehose_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_policy_attachment" "firehose_s3_full_access" {
  name       = "ec2-cloudwatch-full-access-attachment"
  roles      = [aws_iam_role.firehose_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Firehose Policy (Access S3 & Kinesis)
resource "aws_iam_policy" "firehose_policy" {
  name        = "FirehoseS3KinesisPolicy"
  description = "Allows Firehose to read from Kinesis and write to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = [
          aws_s3_bucket.website_monitor_logs.arn,
          "${aws_s3_bucket.website_monitor_logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListStreams"
        ]
        Resource = "arn:aws:kinesis:*:*:stream/*" 
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

# ----------------------------
# Kinesis Firehose Delivery Stream
# ----------------------------
resource "aws_kinesis_firehose_delivery_stream" "website_firehose" {
  name        = "website-ordered-delivery-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.mywebsiteorder.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.website_monitor_logs.arn
    prefix             = "processed/" # Store data inside processed folder
    buffering_size     = 1            # 1MB buffer
    buffering_interval = 30           # 30 seconds
    compression_format = "GZIP"       # Compress logs

    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.website_monitoring_lambda.arn}:$LATEST"
        }
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/website-ordered-delivery-stream"
      log_stream_name = "S3Delivery"
    }
  }

  tags = {
    Name = "Website Ordered Delivery Stream"
  }
}

# ----------------------------
# IAM Role for Firehose (Allow invoking Lambda)
# ----------------------------
resource "aws_iam_role_policy" "firehose_lambda_invoke" {
  name   = "firehose_lambda_invoke"
  role   = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = aws_lambda_function.website_monitoring_lambda.arn
      }
    ]
  })
}