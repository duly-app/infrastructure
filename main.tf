terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key     = "terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = "eu-north-1"
}
