output "instance_ids" {
  description = "Map of node name to EC2 instance ID."
  value       = { for name, instance in aws_instance.node : name => instance.id }
}

output "instance_private_ips" {
  description = "Map of node name to private IP address."
  value       = { for name, instance in aws_instance.node : name => instance.private_ip }
}

output "security_group_id" {
  description = "ID of the Kubernetes intra-cluster security group."
  value       = aws_security_group.k8s.id
}

output "join_command_parameter" {
  description = "SSM parameter name holding the kubeadm join command published by the control plane."
  value       = local.join_parameter_name
}
