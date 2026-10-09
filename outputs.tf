output "private_subnet_cidr_blocks" {
  description = "CIDR blocks of the three private subnets."
  value       = module.vpc.private_subnets_cidr_blocks
}

output "private_subnet_ids" {
  description = "IDs of the three private subnets, ordered by availability zone."
  value       = module.vpc.private_subnets
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
