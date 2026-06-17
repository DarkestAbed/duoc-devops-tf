# ==============================================================================
# ROOT MODULE
# Orchestrates network (VPC/subnets/route tables), security groups, EKS cluster,
# and ECR repositories. The network is created in this repo by the network module
# — there is no reliance on a pre-existing VPC or a separate state.
# ==============================================================================

# ==============================================================================
# NETWORK MODULE
# Creates the VPC (academy-vpc), public/private-app/private-data subnets,
# Internet Gateway, NAT Gateway, and route tables.
# Kubernetes subnet tags are passed in here so LoadBalancer Services work
# without needing separate aws_ec2_tag resources.
# ==============================================================================

module "network" {
  source = "./modules/network"

  vpc_cidr = var.vpc_cidr
  azs      = var.azs
  tags     = var.common_tags

  # Mark every subnet as shared by this cluster.
  subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  # Public subnets host external LoadBalancers.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  # Private subnets host internal LoadBalancers.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ==============================================================================
# LOCALS
# Convenience aggregations of subnet IDs from the network module.
# ==============================================================================

locals {
  vpc_id   = module.network.vpc_id
  vpc_cidr = module.network.vpc_cidr

  all_subnet_ids = concat(
    module.network.public_subnet_ids,
    module.network.private_app_subnet_ids,
    module.network.private_data_subnet_ids
  )
  private_subnet_ids = concat(
    module.network.private_app_subnet_ids,
    module.network.private_data_subnet_ids
  )
}

data "aws_caller_identity" "current" {}

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

  # Subnets (with their kubernetes.io tags) must exist before the cluster.
  depends_on = [module.network]
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = var.ecr_repo_names
  tags             = var.common_tags
}