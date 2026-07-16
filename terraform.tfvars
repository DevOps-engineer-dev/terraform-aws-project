# Copy this file to terraform.tfvars and adjust as needed.
# terraform.tfvars is gitignored on purpose - keep environment-specific
# values out of version control if they ever become sensitive.

aws_region   = "us-east-1"
project_name = "web-app"
environment  = "dev"

vpc_cidr = "10.0.0.0/16"

availability_zones = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

instance_type = "t3.micro"
