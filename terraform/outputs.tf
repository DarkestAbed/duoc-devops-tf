# ==============================================================================
# ROOT OUTPUTS
# Values needed for kubectl connection, ECR push, and validation.
# ==============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "kubeconfig_command" {
  description = "Command to update kubectl config for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
}

output "ecr_repository_urls" {
  description = "Map of ECR repository names to their URLs"
  value       = module.ecr.repository_urls
}

output "ecr_login_command" {
  description = "Command to authenticate Docker with ECR"
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
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