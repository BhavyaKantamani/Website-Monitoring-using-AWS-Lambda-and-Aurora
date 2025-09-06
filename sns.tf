# Create SNS Topic
resource "aws_sns_topic" "website_monitoring_alert" {
  name = "website-monitoring-alert"
}

# Subscribe Email to SNS Topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.website_monitoring_alert.arn
  protocol  = "email"
  endpoint  = "bhavyakantamani@gmail.com"
}

# Output the SNS Topic ARN
output "sns_topic_arn" {
  value = aws_sns_topic.website_monitoring_alert.arn
}