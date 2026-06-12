# ==============================================================================
# GLOBAL VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/20"
}

variable "azs" {
  description = "Availability Zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_web_cidr" {
  description = "CIDR allowed to reach web tier (HTTP/SSH/ICMP). Restrict in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance type for all tiers"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Custom AMI ID (leave empty to use latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of an existing AWS EC2 Key Pair for SSH access. MUST be created in the AWS console before running Terraform."
  type        = string

  validation {
    condition     = length(var.key_name) > 0
    error_message = "key_name must be a non-empty string. Create a key pair in AWS EC2 > Key Pairs and pass its name here."
  }
}

variable "iam_role_name" {
  description = "Pre-existing IAM role name for EC2 instances (AWS Academy uses 'LabRole')"
  type        = string
  default     = "LabRole"
}

variable "user_data_web" {
  description = "User data shell script for the bastion/web instance"
  type        = string
  default     = ""
}

variable "user_data_app" {
  description = "User data shell script for the app instance"
  type        = string
  default     = ""
}

variable "user_data_datos" {
  description = "User data shell script for the datos instance"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
