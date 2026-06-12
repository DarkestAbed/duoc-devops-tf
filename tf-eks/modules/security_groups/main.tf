# ==============================================================================
# SECURITY GROUPS MODULE
# Creates security groups for the EKS cluster and node group.
# Pattern follows tf/modules/security_groups: chained SGs with descriptive names.
#
# SGs are created empty first, then rules are added as separate resources
# to avoid circular dependencies between sg_cluster and sg_nodes.
# ==============================================================================

# ==============================================================================
# EKS CLUSTER SECURITY GROUP
# ==============================================================================

resource "aws_security_group" "sg_cluster" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "eks-cluster-sg"
  })
}

# ==============================================================================
# EKS NODE SECURITY GROUP
# ==============================================================================

resource "aws_security_group" "sg_nodes" {
  name        = "eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "eks-nodes-sg"
  })
}

# ==============================================================================
# CLUSTER SG RULES
# ==============================================================================

resource "aws_security_group_rule" "cluster_vpc_ingress" {
  description       = "Allow all traffic from VPC CIDR (kubectl and internal communication)"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.sg_cluster.id
}

resource "aws_security_group_rule" "cluster_nodes_ingress" {
  description              = "Allow traffic from EKS node security group"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.sg_nodes.id
  security_group_id        = aws_security_group.sg_cluster.id
}

# ==============================================================================
# NODE SG RULES
# ==============================================================================

resource "aws_security_group_rule" "nodes_cluster_ingress" {
  description              = "Allow traffic from EKS cluster security group"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.sg_cluster.id
  security_group_id        = aws_security_group.sg_nodes.id
}

resource "aws_security_group_rule" "nodes_self_ingress" {
  description       = "Inter-node communication within the node group"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.sg_nodes.id
}

resource "aws_security_group_rule" "nodes_http_ingress" {
  description       = "Frontend HTTP access (LoadBalancer)"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_nodes.id
}

resource "aws_security_group_rule" "nodes_backend_ingress" {
  description       = "Backend API port (NodeJS) from VPC"
  type              = "ingress"
  from_port         = 3001
  to_port           = 3001
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.sg_nodes.id
}

resource "aws_security_group_rule" "nodes_mysql_ingress" {
  description       = "MySQL port from VPC"
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.sg_nodes.id
}