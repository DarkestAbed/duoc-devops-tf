# ==============================================================================
# EKS MODULE
# Provisions EKS cluster, node group, CloudWatch logs, and add-ons.
# ==============================================================================

# ==============================================================================
# IAM ROLE DATA SOURCES
# AWS Academy does not grant students iam:CreateRole permission.
# The roles LabEKSClusterRole and LabEKSNodeRole must be created manually
# in the AWS IAM Console BEFORE running terraform apply.
# See README.md for step-by-step instructions.
# ==============================================================================

data "aws_iam_role" "cluster_role" {
  name = var.cluster_role_name
}

data "aws_iam_role" "node_role" {
  name = var.node_role_name
}

# ==============================================================================
# CLOUDWATCH LOG GROUP
# Stores control plane logs for API server, audit, authenticator, etc.
# Created explicitly to control retention and tagging.
# ==============================================================================

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-logs"
  })
}

# ==============================================================================
# EKS CLUSTER
# ==============================================================================

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = data.aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = var.cluster_sg_ids
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

# ==============================================================================
# EKS NODE GROUP
# Uses SPOT instances for cost optimization in the lab environment.
# ==============================================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = data.aws_iam_role.node_role.arn
  subnet_ids      = var.subnet_ids

  capacity_type  = "SPOT"
  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nodes"
  })
}

# ==============================================================================
# EKS ADD-ONS
# ==============================================================================

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc-cni"
  })
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cloudwatch-observability"
  })
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-metrics-server"
  })
}