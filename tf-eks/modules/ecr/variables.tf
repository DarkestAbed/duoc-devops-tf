# ==============================================================================
# ECR MODULE VARIABLES
# ==============================================================================

variable "repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}