terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ---------------------------------------------------------------------
  # Remote state backend (S3 + DynamoDB lock table).
  #
  # This is intentionally commented out to start. Terraform state cannot
  # bootstrap its own backend, so the S3 bucket and DynamoDB table below
  # must exist BEFORE you uncomment this block. See README.md section
  # "Bootstrap remote state" for the one-time manual commands.
  #
  # Once the bucket/table exist, uncomment this block, fill in your own
  # values, and run `terraform init -migrate-state` once locally to move
  # your local state into S3.
  # ---------------------------------------------------------------------
  backend "s3" {
    bucket         = "hamza-terraform-aws"
    key            = "web-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
