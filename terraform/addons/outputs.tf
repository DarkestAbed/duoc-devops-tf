# ==============================================================================
# addons/ ROOT OUTPUTS
# ==============================================================================

output "kubeconfig_command" {
  description = "Command to update kubectl config for the EKS cluster managed by the sibling cluster/ root."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${data.terraform_remote_state.cluster.outputs.cluster_name}"
}

output "lbc_release_name" {
  description = "Name of the Helm release for the AWS Load Balancer Controller."
  value       = helm_release.aws_load_balancer_controller.name
}

output "lbc_namespace" {
  description = "Kubernetes namespace the AWS Load Balancer Controller is installed into."
  value       = helm_release.aws_load_balancer_controller.namespace
}

output "aws_credentials_secret_name" {
  description = "Name of the Kubernetes Secret holding the AWS credentials the LBC uses."
  value       = kubernetes_secret.aws_credentials.metadata[0].name
}