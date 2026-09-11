resource "aws_instance" "duly-instance" {
  ami           = "ami-051c6296b8d2535f1"
  instance_type = "t3.small"

  tags = {
    Name        = "duly-instance"
    Project     = "duly"
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "lawrence"
    CostCenter  = "portfolio"
  }
}