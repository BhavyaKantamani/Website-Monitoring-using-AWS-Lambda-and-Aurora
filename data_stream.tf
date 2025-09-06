resource "aws_kinesis_stream" "mywebsiteorder" {
  name             = "mywebsiteorder"
  retention_period = 24 # Retention period in hours (default is 24)

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
    Project = "AWS Project-Website Monitoring"
  }
}
