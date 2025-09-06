# IAM Role for EC2 with Kinesis Full Access
resource "aws_iam_role" "ec2_kinesis_role" {
  name = "ec2-kinesis-full-access-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach Kinesis Full Access Policy to the Role
resource "aws_iam_policy_attachment" "kinesis_full_access" {
  name       = "ec2-kinesis-full-access-attachment"
  roles      = [aws_iam_role.ec2_kinesis_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}

# Attach CloudWatch Full Access Policy
resource "aws_iam_policy_attachment" "cloudwatch_full_access" {
  name       = "ec2-cloudwatch-full-access-attachment"
  roles      = [aws_iam_role.ec2_kinesis_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-kinesis-instance-profile"
  role = aws_iam_role.ec2_kinesis_role.name
}

# Security Group to allow SSH from all
resource "aws_security_group" "web_log_sg" {
  name        = "web-log-simulation-sg"
  description = "Allow SSH from all"
  vpc_id      = aws_vpc.aurora_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance with Kinesis Agent Configuration
resource "aws_instance" "web_log_simulation" {
  ami                    = "ami-05716d7e60b53d380" # Amazon Linux 2 AMI
  instance_type          = "t2.micro"
  key_name               = "pro2" # change to your keypair name
  subnet_id              = aws_subnet.public_subnet_1.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [aws_security_group.web_log_sg.id]

  tags = {
    Name = "web-log-simulation"
  }

  # User Data Script to install and configure Kinesis Agent
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system and install Kinesis Agent
    sudo yum update -y
    sudo yum install -y aws-kinesis-agent

    # Create the log directory
    sudo mkdir -p /var/log/mywebsite
    sudo chmod 777 /var/log/mywebsite

    # Configure Kinesis Agent
    cat <<EOT | sudo tee /etc/aws-kinesis/agent.json
    {
        "cloudwatch.emitMetrics": true,
        "kinesis.endpoint": "kinesis.us-east-2.amazonaws.com",
        "firehose.endpoint": "",
        "flows": [
            {
                "filePattern": "/var/log/mywebsite/*.log",
                "kinesisStream": "mywebsiteorder",
                "partitionKeyOption": "RANDOM",
                "dataProcessingOptions": [
                    {
                        "optionName": "CSVTOJSON",
                        "customFieldNames": [
                            "InvoiceNo",
                            "StockCode",
                            "Description",
                            "Quantity",
                            "InvoiceDate",
                            "UnitPrice",
                            "Customer",
                            "Country"
                        ]
                    }
                ]
            }
        ]
    }
    EOT

    # Restart the Kinesis Agent
    sudo systemctl enable aws-kinesis-agent
    sudo systemctl restart aws-kinesis-agent

    echo "Kinesis Agent setup completed!" >> /home/ec2-user/setup.log
  EOF
}
