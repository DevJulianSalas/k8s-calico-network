output "k8s_security_group_id" {
  description = "ID of the Kubernetes intra-cluster security group."
  value       = module.compute.security_group_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways providing outbound internet access for private subnets."
  value       = module.vpc.natgw_ids
}

output "nat_public_ips" {
  description = "Public Elastic IPs associated with the NAT gateways."
  value       = module.vpc.nat_public_ips
}

output "node_instance_ids" {
  description = "Map of cluster node name to EC2 instance ID."
  value       = module.compute.instance_ids
}

output "node_private_ips" {
  description = "Map of cluster node name to private IP address."
  value       = module.compute.instance_private_ips
}

output "private_subnet_cidr_blocks" {
  description = "CIDR blocks of the three private subnets."
  value       = module.vpc.private_subnets_cidr_blocks
}

output "private_subnet_ids" {
  description = "IDs of the three private subnets, ordered by availability zone."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets hosting the NAT gateway."
  value       = module.vpc.public_subnets
}

output "vpc_arn" {
  description = "ARN of the created VPC."
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the created VPC."
  value       = module.vpc.vpc_cidr_block
}

output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}
