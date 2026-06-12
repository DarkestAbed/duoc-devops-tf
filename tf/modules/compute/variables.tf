variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty to use latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair to attach to instances"
  type        = string
}

variable "iam_role_name" {
  description = "Name of the IAM role to attach via instance profile"
  type        = string
  default     = "LabRole"
}

variable "web_subnet_id" {
  description = "Subnet ID for the web/bastion instance"
  type        = string
}

variable "app_subnet_id" {
  description = "Subnet ID for the app instance"
  type        = string
}

variable "datos_subnet_id" {
  description = "Subnet ID for the datos instance"
  type        = string
}

variable "sg_web_id" {
  description = "Security group ID for the web tier"
  type        = string
}

variable "sg_app_id" {
  description = "Security group ID for the app tier"
  type        = string
}

variable "sg_datos_id" {
  description = "Security group ID for the data tier"
  type        = string
}

variable "user_data_web" {
  description = "User data script for the web instance"
  type        = string
  default     = ""
}

variable "user_data_app" {
  description = "User data script for the app instance"
  type        = string
  default     = ""
}

variable "user_data_datos" {
  description = "User data script for the datos instance"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
