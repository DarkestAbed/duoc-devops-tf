# ==============================================================================
# GLOBAL VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC created by the network module"
  type        = string
  default     = "10.0.0.0/20"
}

variable "azs" {
  description = "Availability Zones to spread subnets across. Must be at least 2 for EKS."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "tienda-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "cluster_role_name" {
  description = "Pre-existing IAM role name for the EKS cluster. AWS Academy provides 'LabRole' which trusts both eks.amazonaws.com and ec2.amazonaws.com."
  type        = string
  default     = "LabRole"
}

variable "node_role_name" {
  description = "Pre-existing IAM role name for EKS node group. AWS Academy provides 'LabRole' which trusts ec2.amazonaws.com."
  type        = string
  default     = "LabRole"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.large"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes in the node group"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes in the node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes in the node group"
  type        = number
  default     = 3
}

variable "ecr_repo_names" {
  description = "Names of ECR repositories to create for the Tienda application"
  type        = list(string)
  default     = ["tienda-frontend", "tienda-backend", "tienda-db"]
}

variable "common_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}