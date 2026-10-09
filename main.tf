terraform {
  required_version = ">= 1.14.0"

  backend "s3" {
    # Leave bucket, key, region, and locking settings blank.
    # These parameters are injected dynamically via a backend config file (backend.tfbackend).
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.profile

  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

  lifecycle {
    postcondition {
      condition     = length(self.names) >= 3
      error_message = "The selected region must expose at least three availability zones."
    }
  }
}

locals {
  environment = lookup({
    default = "dev"
    dev     = "dev"
    staging = "staging"
    prod    = "prod"
  }, terraform.workspace, "dev")

  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnet_cidrs = [
    for idx in range(3) : cidrsubnet(var.vpc_cidr, var.subnet_newbits, idx)
  ]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7.3"

  name = "${var.project_name}-${local.environment}"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnet_cidrs

  enable_dns_support   = true
  enable_dns_hostnames = true
  enable_ipv6          = false

  create_igw                       = false
  enable_nat_gateway               = false
  create_private_nat_gateway_route = false
  map_public_ip_on_launch          = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  manage_default_network_acl = false
  manage_default_route_table = false

  enable_flow_log = false

  private_subnet_tags = {
    Tier = "private"
  }

  tags = local.common_tags
}
