# ==============================================================================
# TERRAFORM AND PROVIDER CONFIGURATION — addons/ root
# Installs Kubernetes add-ons (the AWS Load Balancer Controller) on top of a
# cluster created by the sibling cluster/ root. Reads cluster outputs via
# `terraform_remote_state` — the cluster/ root must have been applied at
# least once before this root can plan.
# ==============================================================================

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
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

# ==============================================================================
# READ CLUSTER OUTPUTS FROM THE SIBLING cluster/ ROOT
#
# `path` is relative to this root's working directory. Run `terraform init`
# and `terraform apply` from inside terraform/addons/ — not from the project
# root, not from terraform/.
# ==============================================================================

data "terraform_remote_state" "cluster" {
  backend = "local"
  config  = { path = "../cluster/terraform.tfstate" }
}

locals {
  eks_endpoint = data.terraform_remote_state.cluster.outputs.cluster_endpoint
  eks_ca       = base64decode(data.terraform_remote_state.cluster.outputs.cluster_ca_data)
}

# ==============================================================================
# KUBERNETES + HELM PROVIDERS
# Wired to the EKS cluster via exec auth (aws eks get-token) so no local
# kubeconfig file is required. Host + CA come from the sibling cluster/
# root's outputs (via terraform_remote_state).
# ==============================================================================

provider "kubernetes" {
  host                   = local.eks_endpoint
  cluster_ca_certificate = local.eks_ca
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.cluster.outputs.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.eks_endpoint
    cluster_ca_certificate = local.eks_ca
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.cluster.outputs.cluster_name, "--region", var.region]
    }
  }
}