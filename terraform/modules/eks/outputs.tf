# ==============================================================================
# EKS MODULE OUTPUTS
# ==============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate data for the EKS cluster API server. Consumed by the kubernetes/helm providers in the addons/ root via terraform_remote_state."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID created by EKS for the cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  description = "Name of the EKS node group"
  value       = aws_eks_node_group.main.node_group_name
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = aws_eks_node_group.main.arn
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS control plane"
  value       = aws_cloudwatch_log_group.eks_cluster.arn
}