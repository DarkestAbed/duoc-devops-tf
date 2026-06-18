# ==============================================================================
# cluster/ ROOT OUTPUTS
# Values needed for kubectl connection, ECR push, and downstream consumption
# by the addons/ root (which reads these via terraform_remote_state).
# ==============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  description = "Base64-encoded CA data for the EKS cluster API server. Consumed by the kubernetes/helm providers in addons/."
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "ID of the VPC where EKS is deployed"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "Map of subnet group IDs created by the network module"
  value = {
    public       = module.network.public_subnet_ids
    private_app  = module.network.private_app_subnet_ids
    private_data = module.network.private_data_subnet_ids
  }
}

output "node_group_name" {
  description = "Name of the EKS node group"
  value       = module.eks.node_group_name
}

output "ecr_repository_urls" {
  description = "Map of ECR repository names to their URLs"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of ECR repository names to their ARNs"
  value       = module.ecr.repository_arns
}

output "account_id" {
  description = "AWS account ID where the cluster is deployed. Useful for building ECR login commands from the shell."
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_login_command" {
  description = "Command to authenticate Docker with ECR"
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}