# ==============================================================================
# addons/ ROOT MODULE
# Installs Kubernetes add-ons (the AWS Load Balancer Controller Helm release
# and its aws-credentials Secret) on top of a cluster created by the sibling
# cluster/ root. Reads the cluster endpoint, CA data, and VPC ID from
# `terraform_remote_state` — the cluster/ root must have been applied at
# least once before this root can plan.
# ==============================================================================

# ==============================================================================
# READ AWS CREDENTIALS FROM THE SHELL ENVIRONMENT
#
# The lab's `export_vars.sh` exports AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
# / AWS_SESSION_TOKEN (the names the AWS CLI and SDKs use), not TF_VAR_*
# mirrors. To avoid asking the student to export the values twice, we read
# the env via the `external` data source: a tiny `jq` invocation prints the
# three vars.
#
# Only evaluated when its result is read (in the locals block below).
# ==============================================================================

data "external" "aws_env" {
  count = var.aws_access_key_id == null && var.aws_secret_access_key == null && var.aws_session_token == null ? 1 : 0

  program = ["sh", "-c", "jq -n --arg k AWS_ACCESS_KEY_ID --arg s AWS_SECRET_ACCESS_KEY --arg t AWS_SESSION_TOKEN '{key_id: (env[$k] // \"\"), access_key: (env[$s] // \"\"), session_token: (env[$t] // \"\")}'"]
}

# ==============================================================================
# LOCALS
# AWS credentials for the LBC pod. Resolution order:
#   1. var.aws_access_key_id (explicit tfvars or -var flag)
#   2. data.external.aws_env (reads AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#      / AWS_SESSION_TOKEN from the shell environment — the names the
#      student's export_vars.sh script already exports)
#   3. empty string (caught by the check block below)
# ==============================================================================

locals {
  aws_access_key_id     = sensitive(var.aws_access_key_id != null ? var.aws_access_key_id : try(data.external.aws_env[0].result.key_id, ""))
  aws_secret_access_key = sensitive(var.aws_secret_access_key != null ? var.aws_secret_access_key : try(data.external.aws_env[0].result.access_key, ""))
  aws_session_token     = sensitive(var.aws_session_token != null ? var.aws_session_token : try(data.external.aws_env[0].result.session_token, ""))
}

# ==============================================================================
# PRE-APPLY CHECK: AWS credentials must be set in the environment (or in
# terraform.tfvars). Fires on every plan/apply, even when no resources would
# change, so a forgotten `source export_vars.sh` is caught before side effects.
# `check` blocks are read-only — they cannot mutate state.
# ==============================================================================

check "aws_credentials_present" {
  assert {
    condition     = local.aws_access_key_id != "" && local.aws_secret_access_key != "" && local.aws_session_token != ""
    error_message = "AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN must be set in the apply environment. Run 'source terraform/export_vars.sh' (or paste the AWS Academy creds manually) and re-run terraform plan/apply. These three env vars are mounted into the LBC pod as AWS credentials via a Kubernetes Secret."
  }
}

# ==============================================================================
# AWS CREDENTIALS SECRET (for the LBC)
#
# AWS Academy students cannot create or attach IAM roles, so the LBC cannot
# use IRSA. The LBC pod runs with the student's own voclabs session credentials
# injected as env vars.
#
# NOTE: this kubernetes provider build (hashicorp/kubernetes v2.38.0) base64
# encodes `data` itself on write AND does not support `string_data`. So the
# values here MUST be PLAINTEXT — wrapping them in base64encode() produces a
# double-encoded Secret (the LBC then receives a base64 blob as its AWS_ACCESS
# KEY_ID and AWS rejects it with `InvalidClientTokenId`). Pass plaintext; the
# provider encodes once, Kubernetes stores base64, and the LBC decodes once.
#
# The Secret is rewritten on every apply, so refreshing Academy creds only needs:
#   1. source fresh creds into the shell env (export_vars.sh / ~/.aws/credentials)
#   2. terraform apply   (re-reads env via data.external.aws_env, rewrites Secret)
#   3. kubectl -n kube-system rollout restart deploy/aws-load-balancer-controller
#      (envFrom is only read at pod start, so the pod must restart to pick up
#      the new Secret)
# ==============================================================================

resource "kubernetes_secret" "aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "credentials"
    }
  }

  data = {
    AWS_ACCESS_KEY_ID     = local.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = local.aws_secret_access_key
    AWS_SESSION_TOKEN     = local.aws_session_token
  }

  type = "Opaque"

  depends_on = [data.terraform_remote_state.cluster]
}

# ==============================================================================
# AWS LOAD BALANCER CONTROLLER (Helm release)
#
# Installs the LBC into kube-system. AWS Academy blocks iam:CreateRole, so
# IRSA is unavailable — the controller uses the env-var credentials above
# instead. The chart renders `.Values.envFrom` as a pass-through envFrom block;
# the three Secret keys become pod env vars and the AWS SDK picks them up
# before falling back to IMDS.
# ==============================================================================

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.cluster.outputs.cluster_name
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.cluster.outputs.vpc_id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "replicaCount"
    value = "1"
  }
  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }
  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # Inject the AWS creds Secret into the controller pod. If the chart version
  # we pull does not render .Values.envFrom, this set is a no-op and the pod
  # falls back to IMDS (node role, which lacks ELB perms) — detectable in logs.
  # Fallback: switch to `values = [yamlencode({ env = [...] valueFrom ... })]`.
  set {
    name  = "envFrom[0].secretRef.name"
    value = kubernetes_secret.aws_credentials.metadata[0].name
  }

  depends_on = [
    data.terraform_remote_state.cluster,
    kubernetes_secret.aws_credentials,
  ]
}