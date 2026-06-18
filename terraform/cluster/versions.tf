# ==============================================================================
# TERRAFORM AND PROVIDER CONFIGURATION — cluster/ root
# Provisions AWS infrastructure only: VPC, security groups, EKS, ECR.
# No kubernetes/helm/external providers here. The kubernetes add-ons (LBC,
# AWS-credentials Secret) live in the sibling addons/ root and read this
# root's outputs through terraform_remote_state.
# ==============================================================================

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "aws" {
  region = var.region
}