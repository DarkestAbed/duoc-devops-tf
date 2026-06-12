## genai generated code for deploying networks on aws student

################################################################################
# PROJECT: AWS Academy Network Infrastructure
# DESCRIPTION: This Terraform script lays the froundwork for Terraform execution
#              to deploy the required lab infrastructure.
################################################################################

# --- Provider Configuration ---
# Configures the AWS provider. Ensure environment variables for credentials
# (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN) are set.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
