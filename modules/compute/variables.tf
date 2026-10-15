variable "ami_id" {
  description = "Optional arm64 AMI ID override. Defaults to the latest Amazon Linux 2023 arm64 AMI."
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

variable "environment" {
  description = "Deployment environment name used for naming and tagging."
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances to create."
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
}

variable "root_volume_size" {
  description = "Size in GiB of the encrypted gp3 root volume for each instance."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GiB."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs the instances are distributed across."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID is required."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by the module."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the VPC the instances and security group belong to."
  type        = string
}
