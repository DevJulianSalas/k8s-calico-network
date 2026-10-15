data "aws_ssm_parameter" "al2023_arm64" {
  count = var.ami_id == null ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node" {
  statement {
    sid       = "JoinCommandParameter"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter"]
    resources = [local.join_parameter_arn]
  }

  statement {
    sid       = "JoinCommandDecryption"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

locals {
  k8s_ports = {
    api_server         = { port = 6443, protocol = "tcp" }
    etcd_client        = { port = 2379, protocol = "tcp" }
    etcd_peer          = { port = 2380, protocol = "tcp" }
    kubelet            = { port = 10250, protocol = "tcp" }
    controller_manager = { port = 10257, protocol = "tcp" }
    scheduler          = { port = 10259, protocol = "tcp" }
    calico_bgp         = { port = 179, protocol = "tcp" }
    calico_vxlan       = { port = 4789, protocol = "udp" }
  }

  join_parameter_name = "/${var.project_name}/${var.environment}/k8s/join-command"
  join_parameter_arn  = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.join_parameter_name}"

  nodes = {
    for idx in range(var.instance_count) : "node-${idx + 1}" => {
      role      = idx < var.control_plane_count ? "control-plane" : "worker"
      subnet_id = element(var.subnet_ids, idx % length(var.subnet_ids))
    }
  }

  control_plane_user_data = join("\n", [
    "#!/bin/bash",
    "export PARAM_NAME='${local.join_parameter_name}'",
    "export POD_NETWORK_CIDR='${var.pod_network_cidr}'",
    file("${path.module}/scripts/control-plane.sh"),
  ])

  worker_user_data = join("\n", [
    "#!/bin/bash",
    "export PARAM_NAME='${local.join_parameter_name}'",
    file("${path.module}/scripts/worker.sh"),
  ])
}

resource "aws_iam_role" "node" {
  name               = "${var.project_name}-${var.environment}-k8s-node"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-k8s-node"
  })
}

resource "aws_iam_role_policy" "node" {
  name   = "${var.project_name}-${var.environment}-k8s-node"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.project_name}-${var.environment}-k8s-node"
  role = aws_iam_role.node.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-k8s-node"
  })
}

resource "aws_security_group" "k8s" {
  name        = "${var.project_name}-${var.environment}-k8s"
  description = "Kubernetes intra-cluster communication"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-k8s"
  })
}

resource "aws_vpc_security_group_ingress_rule" "k8s" {
  for_each = local.k8s_ports

  security_group_id            = aws_security_group.k8s.id
  description                  = "Kubernetes ${replace(each.key, "_", " ")}"
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = each.value.protocol
  referenced_security_group_id = aws_security_group.k8s.id
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.k8s.id
  description       = "Outbound internet (image pulls) and intra-cluster traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "node" {
  for_each = local.nodes

  ami                         = coalesce(var.ami_id, one(data.aws_ssm_parameter.al2023_arm64[*].value))
  instance_type               = var.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [aws_security_group.k8s.id]
  iam_instance_profile        = aws_iam_instance_profile.node.name
  user_data                   = each.value.role == "control-plane" ? local.control_plane_user_data : local.worker_user_data
  user_data_replace_on_change = true
  associate_public_ip_address = false
  monitoring                  = false

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}"
    Role = each.value.role
  })
}
