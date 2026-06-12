# ==============================================================================
# SECURITY GROUPS MODULE OUTPUTS
# ==============================================================================

output "sg_cluster_id" {
  description = "ID of the EKS cluster security group"
  value       = aws_security_group.sg_cluster.id
}

output "sg_nodes_id" {
  description = "ID of the EKS nodes security group"
  value       = aws_security_group.sg_nodes.id
}