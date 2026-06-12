# ==============================================================================
# ROOT MODULE
# Orchestrates security groups, EKS cluster, and ECR repositories.
# Discovers the existing VPC created by the tf/ infrastructure module.
# ==============================================================================

# ==============================================================================
# VPC DATA SOURCE
# If vpc_id is provided, use it directly. Otherwise, discover by tag.
# ==============================================================================

data "aws_vpc" "selected" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

data "aws_vpc" "academy" {
  count = var.vpc_id == "" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["academy-vpc"]
  }
}

locals {
  vpc_id   = var.vpc_id != "" ? data.aws_vpc.selected[0].id : data.aws_vpc.academy[0].id
  vpc_cidr = var.vpc_id != "" ? data.aws_vpc.selected[0].cidr_block : data.aws_vpc.academy[0].cidr_block
}

# ==============================================================================
# SUBNET DATA SOURCES
# Discover subnets by VPC ID and Name tags.
# ==============================================================================

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["public-subnet-*"]
  }
}

data "aws_subnets" "private_app" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["private-app-subnet-*"]
  }
}

data "aws_subnets" "private_data" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["private-data-subnet-*"]
  }
}

data "aws_caller_identity" "current" {}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  all_subnet_ids = concat(
    data.aws_subnets.public.ids,
    data.aws_subnets.private_app.ids,
    data.aws_subnets.private_data.ids
  )
  private_subnet_ids = concat(
    data.aws_subnets.private_app.ids,
    data.aws_subnets.private_data.ids
  )
}

# ==============================================================================
# SUBNET TAGGING FOR KUBERNETES
# CRITICAL: Without these tags, Service type LoadBalancer stays Pending forever.
# Uses aws_ec2_tag to add tags to subnets managed by the tf/ state without
# claiming ownership of those resources.
# ==============================================================================

# All subnets: mark as shared cluster subnets
resource "aws_ec2_tag" "cluster_tag" {
  for_each    = toset(local.all_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

# Public subnets: mark for external LoadBalancer provisioning
resource "aws_ec2_tag" "public_elb_tag" {
  for_each    = toset(data.aws_subnets.public.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# Private subnets: mark for internal LoadBalancer provisioning
resource "aws_ec2_tag" "internal_elb_tag" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# ==============================================================================
# MODULES
# ==============================================================================

module "security_groups" {
  source = "./modules/security_groups"

  vpc_id   = local.vpc_id
  vpc_cidr = local.vpc_cidr
  tags     = var.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  cluster_role_name  = var.cluster_role_name
  node_role_name     = var.node_role_name
  subnet_ids         = local.all_subnet_ids
  cluster_sg_ids     = [module.security_groups.sg_cluster_id, module.security_groups.sg_nodes_id]
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  tags               = var.common_tags

  depends_on = [
    aws_ec2_tag.cluster_tag,
    aws_ec2_tag.public_elb_tag,
    aws_ec2_tag.internal_elb_tag,
  ]
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = var.ecr_repo_names
  tags             = var.common_tags
}