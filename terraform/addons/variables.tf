# ==============================================================================
# addons/ ROOT VARIABLES
# The addons/ root has no AWS IAM or network prerequisites of its own — it
# only needs the AWS creds it mounts into the LBC pod, and the region/cluster
# name (used to wire the kubernetes/helm providers).
# ==============================================================================

variable "region" {
  description = "AWS region to deploy into. Must match the region used by the sibling cluster/ root."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Must match var.cluster_name in the sibling cluster/ root."
  type        = string
  default     = "tienda-eks"
}

variable "common_tags" {
  description = "Tags to apply to the LBC's Kubernetes Secret (forwarded as labels)."
  type        = map(string)
  default     = {}
}

# --- AWS credentials for the AWS Load Balancer Controller ---
# Leave at null to read them from the shell environment (export_vars.sh) via
# the `external` data source in main.tf. Set explicitly in terraform.tfvars to
# override.

variable "aws_access_key_id" {
  description = "AWS access key for the LBC pod. null = read from env (AWS_ACCESS_KEY_ID)."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_secret_access_key" {
  description = "AWS secret key for the LBC pod. null = read from env (AWS_SECRET_ACCESS_KEY)."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_session_token" {
  description = "AWS session token for the LBC pod. null = read from env (AWS_SESSION_TOKEN)."
  type        = string
  sensitive   = true
  default     = null
}