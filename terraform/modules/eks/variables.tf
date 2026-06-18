# ==============================================================================
# EKS MODULE VARIABLES
# ==============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "cluster_role_name" {
  description = "Pre-existing IAM role name for the EKS cluster"
  type        = string
}

variable "node_role_name" {
  description = "Pre-existing IAM role name for the EKS node group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster control plane"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs for the EKS node group. Defaults to subnet_ids when empty."
  type        = list(string)
  default     = []
}

variable "cluster_sg_ids" {
  description = "Security group IDs for the EKS cluster (applied to control plane and propagated to nodes)"
  type        = list(string)
  default     = []
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.large"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}