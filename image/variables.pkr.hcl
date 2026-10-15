variable "aws_profile" {
  description = "AWS CLI named profile used to build the AMI."
  type        = string
  default     = "REPLACE_WITH_AWS_PROFILE"
}

variable "aws_region" {
  description = "AWS region where the AMI is built and registered."
  type        = string
  default     = "us-west-2"
}

variable "ami_name_prefix" {
  description = "Prefix for the produced AMI name."
  type        = string
  default     = "k8s-calico-al2023-arm64"
}

variable "calico_version" {
  description = "Calico release to bake (tag, including the leading v)."
  type        = string
  default     = "v3.33.0"
}

variable "instance_type" {
  description = "ARM64 build instance type."
  type        = string
  default     = "t4g.small"
}

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. 1.36) installed on the image."
  type        = string
  default     = "1.36"
}
