# ==============================================================================
# cluster/ ROOT MODULE
# Provisions the VPC, security groups, EKS cluster, and ECR repositories.
# Self-contained: no kubernetes/helm providers here, so a greenfield
# `terraform plan` succeeds without depending on a cluster that does not
# exist yet. The addons/ root depends on this one via terraform_remote_state.
# ==============================================================================

data "aws_caller_identity" "current" {}

# ==============================================================================
# READ AWS CREDENTIALS FROM THE SHELL ENVIRONMENT
#
# The lab's `export_vars.sh` exports AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
# / AWS_SESSION_TOKEN (the names the AWS CLI and SDKs use), not TF_VAR_*
# mirrors. To avoid asking the student to export the values twice, we read
# the env via the `external` data source: a tiny `jq` invocation prints the
# three vars. Only evaluated when its result is read (in the locals block
# below).
# ==============================================================================

data "external" "aws_env" {
  count = 1

  program = ["sh", "-c", "jq -n --arg k AWS_ACCESS_KEY_ID --arg s AWS_SECRET_ACCESS_KEY --arg t AWS_SESSION_TOKEN '{key_id: (env[$k] // \"\"), access_key: (env[$s] // \"\"), session_token: (env[$t] // \"\")}'"]
}

# ==============================================================================
# LOCALS
# Subnet tagging required by the AWS Load Balancer Controller to discover
# which subnets to place ALBs/NLBs in. The cluster tag is merged into every
# subnet via `subnet_tags`; the ELB role tags are applied per subnet type
# through `public_subnet_tags` and `private_subnet_tags`.
# ==============================================================================

locals {
  cluster_tag = "kubernetes.io/cluster/${var.cluster_name}"

  subnet_tags = merge(
    var.common_tags,
    {
      (local.cluster_tag) = "shared"
    }
  )

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  all_subnet_ids = concat(
    module.network.public_subnet_ids,
    module.network.private_app_subnet_ids,
    module.network.private_data_subnet_ids,
  )

  vpc_id   = module.network.vpc_id
  vpc_cidr = module.network.vpc_cidr

  # Mirrors the addons/ root's credential resolution so the pre-apply check
  # below can fire from either root.
  aws_access_key_id     = sensitive(try(data.external.aws_env[0].result.key_id, ""))
  aws_secret_access_key = sensitive(try(data.external.aws_env[0].result.access_key, ""))
  aws_session_token     = sensitive(try(data.external.aws_env[0].result.session_token, ""))
}

# ==============================================================================
# PRE-APPLY CHECK: AWS credentials must be set in the environment.
# Fires on every plan/apply, even when no resources would change, so a
# forgotten `source export_vars.sh` is caught before side effects.
# `check` blocks are read-only — they cannot mutate state.
# ==============================================================================

check "aws_credentials_present" {
  assert {
    condition     = local.aws_access_key_id != "" && local.aws_secret_access_key != "" && local.aws_session_token != ""
    error_message = "AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN must be set in the apply environment. Run 'source terraform/export_vars.sh' (or paste the AWS Academy creds manually) and re-run terraform plan/apply."
  }
}

# ==============================================================================
# MODULES
# ==============================================================================

module "network" {
  source = "../modules/network"

  vpc_cidr                   = var.vpc_cidr
  azs                        = var.azs
  public_subnet_newbits      = var.public_subnet_newbits
  public_subnet_offset       = var.public_subnet_offset
  private_app_subnet_offset  = var.private_app_subnet_offset
  private_data_subnet_offset = var.private_data_subnet_offset
  map_public_ip_on_launch    = var.map_public_ip_on_launch
  enable_dns_support         = var.enable_dns_support
  enable_dns_hostnames       = var.enable_dns_hostnames
  subnet_tags                = local.subnet_tags
  public_subnet_tags         = local.public_subnet_tags
  private_subnet_tags        = local.private_subnet_tags
  tags                       = var.common_tags
}

module "security_groups" {
  source = "../modules/security_groups"

  vpc_id   = local.vpc_id
  vpc_cidr = local.vpc_cidr
  tags     = var.common_tags
}

module "eks" {
  source = "../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  cluster_role_name  = var.cluster_role_name
  node_role_name     = var.node_role_name
  subnet_ids         = local.all_subnet_ids
  node_subnet_ids    = local.all_subnet_ids
  cluster_sg_ids     = [module.security_groups.sg_cluster_id, module.security_groups.sg_nodes_id]
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  tags               = var.common_tags

  depends_on = [
    module.network,
    module.security_groups,
  ]
}

module "ecr" {
  source = "../modules/ecr"

  repository_names = var.ecr_repo_names
  tags             = var.common_tags
}