packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
  }
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "amazon-ebs" "k8s" {
  region        = var.aws_region
  profile       = var.aws_profile
  instance_type = var.instance_type
  ssh_username  = "ec2-user"
  ssh_interface = "public_ip"

  associate_public_ip_address               = true
  temporary_security_group_source_public_ip = true

  subnet_filter {
    filters = {
      "default-for-az" = "true"
    }
    most_free = true
  }

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-arm64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      state               = "available"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ami_name     = "${var.ami_name_prefix}-k8s${var.kubernetes_version}-${var.calico_version}-${local.timestamp}"
  encrypt_boot = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name       = "${var.ami_name_prefix}-k8s${var.kubernetes_version}"
    OS         = "Amazon Linux 2023"
    Kubernetes = var.kubernetes_version
    Calico     = var.calico_version
    ManagedBy  = "Packer"
  }
}

build {
  name    = "k8s-calico-al2023"
  sources = ["source.amazon-ebs.k8s"]

  provisioner "file" {
    source      = "${path.root}/files/kubernetes.repo"
    destination = "/tmp/kubernetes.repo"
  }

  provisioner "file" {
    source      = "${path.root}/files/calico/custom-resources.yaml"
    destination = "/tmp/calico-custom-resources.yaml"
  }

  provisioner "file" {
    destination = "/tmp/k8s-versions.env"

    content = <<-EOF
      KUBERNETES_VERSION=${var.kubernetes_version}
      CALICO_VERSION=${var.calico_version}
    EOF
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{.Path}}'"

    scripts = [
      "${path.root}/scripts/01-prereqs.sh",
      "${path.root}/scripts/02-containerd.sh",
      "${path.root}/scripts/03-kubernetes.sh",
      "${path.root}/scripts/04-calico.sh",
      "${path.root}/scripts/05-cleanup.sh",
    ]
  }

  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
  }
}
