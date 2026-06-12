variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/20"
}

variable "azs" {
  description = "List of Availability Zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_newbits" {
  description = "Number of additional bits for public subnets"
  type        = number
  default     = 4
}

variable "public_subnet_offset" {
  description = "Offset for public subnet indices"
  type        = number
  default     = 0
}

variable "private_app_subnet_offset" {
  description = "Offset for private app subnet indices"
  type        = number
  default     = 2
}

variable "private_data_subnet_offset" {
  description = "Offset for private data subnet indices"
  type        = number
  default     = 4
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign public IPs in public subnets"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Create an S3 Gateway VPC endpoint"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
