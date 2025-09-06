# Create DynamoDB Table
resource "aws_dynamodb_table" "website_monitoring_records" {
  name         = "website-monitoring-records"
  billing_mode = "PAY_PER_REQUEST"  # On-demand pricing (no capacity planning needed)

  hash_key  = "CustomerID"  # Primary Key
  range_key = "OrderID"     # Sort Key

  attribute {
    name = "CustomerID"
    type = "N"  # Number
  }

  attribute {
    name = "OrderID"
    type = "S"  # String
  }

  tags = {
    Name        = "website-monitoring-records"
    Environment = "Production"
  }
}


# Output the DynamoDB Table Name
output "dynamodb_table_name" {
  value = aws_dynamodb_table.website_monitoring_records.name
}