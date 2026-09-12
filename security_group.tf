variable "my_ip" {
  description = "The IP address allowed to access the instance via SSH"
  type        = string
  sensitive   = true
  validation {
    condition     = can(cidrhost(var.my_ip, 0))
    error_message = "The provided IP address is not valid."
  }
}

locals {
  ingress_rules = {
    http = {
      description = "Allow HTTP traffic"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    https = {
      description = "Allow HTTPS traffic"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ssh = {
      description = "Allow SSH traffic from my IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["${var.my_ip}"]
    }
  }

  egress_rules = {
    http = {
      description = "Allow HTTP traffic"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    https = {
      description = "Allow HTTPS traffic"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    dns-udp = {
      description = "Allow DNS queries over UDP"
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    dns-tcp = {
      description = "Allow DNS queries over TCP"
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}


resource "aws_security_group" "duly-sg" {
  name   = "duly-sg"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = local.egress_rules
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = {
    Name        = "duly-sg"
    Project     = "duly"
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "lawrence"
    CostCenter  = "portfolio"
  }

  lifecycle {
    create_before_destroy = true
  }
}