# ==============================================================================
# TERRAFORM AND PROVIDER CONFIGURATION
# AWS Academy EKS Cluster Infrastructure
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
# KUBERNETES + HELM PROVIDERS
# Wired to the EKS cluster via exec auth (aws eks get-token) so no local
# kubeconfig file is required. Host + CA come from the aws_eks_cluster data
# source. The cluster must already exist before these providers can plan
# resources (kubernetes_secret / helm_release) — i.e. on a fresh stack the
# LBC install lands on the SECOND apply after the cluster is up.
# ==============================================================================

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

locals {
  eks_endpoint = data.aws_eks_cluster.this.endpoint
  eks_ca       = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
}

provider "kubernetes" {
  host                   = local.eks_endpoint
  cluster_ca_certificate = local.eks_ca
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.eks_endpoint
    cluster_ca_certificate = local.eks_ca
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}