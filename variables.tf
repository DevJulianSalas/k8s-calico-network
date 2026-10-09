variable "aws_region" {
  description = "AWS region in which the VPC is provisioned."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as a prefix for resource naming and tagging."
  type        = string
  default     = "sandbox"
}

variable "profile" {
  description = "AWS CLI profile name to use for authentication."
  type        = string
  default     = "default"
}

variable "subnet_newbits" {
  description = "Number of bits used to extend the VPC CIDR when carving the three private subnets."
  type        = number
  default     = 2

  validation {
    condition     = var.subnet_newbits >= 1 && var.subnet_newbits <= 4
    error_message = "Subnet newbits must be between 1 and 4."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition = (
      can(cidrnetmask(var.vpc_cidr)) &&
      tonumber(split("/", var.vpc_cidr)[1]) >= 16 &&
      tonumber(split("/", var.vpc_cidr)[1]) <= 24
    )
    error_message = "VPC CIDR must be a valid IPv4 CIDR with a prefix between /16 and /24."
  }
}
