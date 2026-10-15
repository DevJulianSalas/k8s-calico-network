variable "aws_region" {
  description = "AWS region in which the VPC is provisioned."
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for the cluster nodes. Defaults to the latest Amazon Linux 2023 arm64 AMI when null."
  type        = string
  default     = null
  nullable    = true
}

variable "control_plane_count" {
  description = "Number of control plane nodes. The first N nodes are control planes; the rest are workers."
  type        = number
  default     = 1

  validation {
    condition     = var.control_plane_count >= 1
    error_message = "At least one control plane node is required."
  }
}

variable "instance_count" {
  description = "Number of EC2 cluster nodes to create."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 6
    error_message = "Instance count must be between 1 and 6."
  }
}

variable "instance_type" {
  description = "ARM64 (Graviton) EC2 instance type for the cluster nodes."
  type        = string
  default     = "t4g.small"

  validation {
    condition = contains(
      ["t4g.nano", "t4g.micro", "t4g.small", "t4g.medium", "t4g.large", "t4g.xlarge", "t4g.2xlarge"],
      var.instance_type
    )
    error_message = "Instance type must be an ARM64 t4g instance type."
  }
}

variable "pod_network_cidr" {
  description = "Cluster pod network CIDR passed to kubeadm and Calico."
  type        = string
  default     = "192.168.0.0/16"
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

variable "root_volume_size" {
  description = "Size in GiB of the encrypted gp3 root volume for each cluster node."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GiB."
  }
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway instead of one per availability zone."
  type        = bool
  default     = true
}

variable "subnet_newbits" {
  description = "Number of bits used to extend the VPC CIDR when carving the public and private subnets."
  type        = number
  default     = 3

  validation {
    condition     = var.subnet_newbits >= 2 && var.subnet_newbits <= 4
    error_message = "Subnet newbits must be between 2 and 4."
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
