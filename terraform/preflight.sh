#!/usr/bin/env bash
# ==============================================================================
# preflight.sh
#
# Pre-apply sanity check for the duoc/intro-devops EKS lab on AWS Academy.
#
# What it does:
#   1. Confirms the AWS CLI is configured and the caller is a voclabs role.
#   2. Detects whether the session is cancelled (`voc-cancel-cred`) and exits
#      with a clear fix message if so.
#   3. Lists IAM roles and locates the EKS cluster + node group roles for the
#      current account. The role names are account-specific (each AWS Academy
#      lab gets a different prefix), so they MUST be discovered — never copied
#      from the example file or another student's repo.
#   4. Compares those discovered names against the values in terraform.tfvars
#      and prints an alert if they don't match. Prints the right block to
#      paste into terraform.tfvars when they do.
#
# Usage:
#   source ../00-export_vars.sh    # or wherever your credentials come from
#   ./preflight.sh
#
# Read-only: makes no API calls that modify state.
# ==============================================================================

set -euo pipefail

# --- pretty output ---------------------------------------------------------
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; NC='\033[0m'
info() { printf "${BLU}[info]${NC} %s\n"  "$*"; }
ok()   { printf "${GRN}[ok]${NC}  %s\n"   "$*"; }
warn() { printf "${YLW}[warn]${NC} %s\n"  "$*"; }
err()  { printf "${RED}[err]${NC}  %s\n"  "$*" >&2; }
hr()   { printf '%s\n' "------------------------------------------------------------"; }

# --- preconditions ---------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  err "aws CLI not found. Install it and re-run."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  err "jq not found. Install it (e.g. 'sudo apt install jq' or 'brew install jq') and re-run."
  exit 1
fi

hr
info "Step 1/3 — Verifying the AWS session"
hr

CALLER="$(aws sts get-caller-identity --output json 2>&1)" || {
  err "aws sts get-caller-identity failed:"
  printf '%s\n' "$CALLER" >&2
  err "Did you run 'source ../00-export_vars.sh' (or equivalent) first?"
  exit 1
}

ACCOUNT_ID="$(printf '%s' "$CALLER" | jq -r '.Account')"
CALLER_ARN="$(printf '%s' "$CALLER" | jq -r '.Arn')"

ok "Caller: $CALLER_ARN"
ok "Account: $ACCOUNT_ID"

# Detect cancelled session: the role's attached policies include
# arn:aws:iam::<account>:policy/voc-cancel-cred.
if printf '%s' "$CALLER_ARN" | grep -qE 'assumed-role/voclabs/'; then
  CANCEL_POLICY="$(aws iam list-attached-role-policies \
    --role-name voclabs \
    --query 'AttachedPolicies[?PolicyName==`voc-cancel-cred`].PolicyName' \
    --output text 2>/dev/null || true)"

  if printf '%s' "$CANCEL_POLICY" | grep -q voc-cancel-cred-1; then
    err "Your AWS Academy lab session is CANCELLED (voc-cancel-cred is attached)."
    err "Fix:"
    err "  1. In Vocareum, click 'Start Lab'. Wait for the dot to go green."
    err "  2. Re-fetch credentials from the AWS Details panel."
    err "  3. Re-source them in your shell:"
    err "       unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN"
    err "       source 00-export_vars.sh   # paste the new values"
    err "  4. Re-run this script."
    exit 2
  else
    ok "Session is active (no voc-cancel-cred policy attached)."
  fi
else
  warn "Caller is not an AWS Academy voclabs role ($CALLER_ARN)."
  warn "Proceeding anyway — this script is still useful for finding the EKS role names."
fi

# --- locate EKS roles ------------------------------------------------------
hr
info "Step 2/3 — Locating the EKS cluster and node group roles"
hr

# Two filter shapes exist in the wild:
#   cXXXXXX...-LabEksClusterRole-<random>      (this account)
#   cXXXXXX...-LabEksNodeRole-<random>
#
# The trailing suffix of the node role prefix is the account id (or a hash
# of it) — varies per lab session. We match by RoleName prefix, not by exact
# name, so this works across accounts.
CLUSTER_ROLE="$(aws iam list-roles \
  --query 'Roles[?starts_with(RoleName, `LabEksClusterRole-`)].RoleName' \
  --output text 2>/dev/null || true)"

NODE_ROLE="$(aws iam list-roles \
  --query 'Roles[?starts_with(RoleName, `LabEksNodeRole-`)].RoleName' \
  --output text 2>/dev/null || true)"

if [ -z "$CLUSTER_ROLE" ] || [ "$CLUSTER_ROLE" = "None" ]; then
  err "No role with prefix 'LabEksClusterRole-' was found in this account."
  err "These roles are pre-created by the AWS Academy lab instructor."
  err "Confirm in IAM > Roles that they exist. If they don't, contact your instructor."
  exit 3
fi

if [ -z "$NODE_ROLE" ] || [ "$NODE_ROLE" = "None" ]; then
  err "No role with prefix 'LabEksNodeRole-' was found in this account."
  err "These roles are pre-created by the AWS Academy lab instructor."
  err "Confirm in IAM > Roles that they exist. If they don't, contact your instructor."
  exit 3
fi

# If multiple LabEksClusterRole-* exist (rare), surface them so the user
# can pick the right one.
CLUSTER_COUNT="$(printf '%s\n' "$CLUSTER_ROLE" | wc -l | tr -d ' ')"
NODE_COUNT="$(printf '%s\n' "$NODE_ROLE" | wc -l | tr -d ' ')"

ok "EKS cluster role(s) found:"
printf '    %s\n' $CLUSTER_ROLE
ok "EKS node group role(s) found:"
printf '    %s\n' $NODE_ROLE

# --- compare with terraform.tfvars -----------------------------------------
hr
info "Step 3/3 — Comparing with terraform.tfvars"
hr

TFVARS_FILE="${TFVARS_FILE:-terraform.tfvars}"
TFVARS_CLUSTER=""
TFVARS_NODE=""

if [ -f "$TFVARS_FILE" ]; then
  # cluster_role_name and node_role_name may have trailing comments after the
  # value; jq isn't a great fit for HCL, so use a tolerant grep.
  TFVARS_CLUSTER="$(grep -E '^cluster_role_name[[:space:]]*=' "$TFVARS_FILE" \
    | head -1 \
    | sed -E 's/^cluster_role_name[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/')"
  TFVARS_NODE="$(grep -E '^node_role_name[[:space:]]*=' "$TFVARS_FILE" \
    | head -1 \
    | sed -E 's/^node_role_name[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/')"
fi

if [ -z "$TFVARS_CLUSTER" ] || [ -z "$TFVARS_NODE" ]; then
  warn "Could not read cluster_role_name / node_role_name from $TFVARS_FILE."
  warn "If you haven't created it yet, copy the example and edit:"
  warn "    cp terraform.tfvars.example terraform.tfvars"
else
  printf '    tfvars cluster_role_name = %s\n' "$TFVARS_CLUSTER"
  printf '    tfvars node_role_name    = %s\n' "$TFVARS_NODE"
fi

# --- final report ----------------------------------------------------------
hr
info "Result"
hr

NEEDS_FIX=0

if [ "$CLUSTER_COUNT" -gt 1 ] || [ "$NODE_COUNT" -gt 1 ]; then
  warn "Multiple candidate roles were found. Pick the one that matches your"
  warn "lab session's account ID prefix and update terraform.tfvars manually."
  NEEDS_FIX=1
elif [ -n "$TFVARS_CLUSTER" ] && [ "$TFVARS_CLUSTER" != "$CLUSTER_ROLE" ]; then
  err "cluster_role_name in $TFVARS_FILE does NOT match the role in this account."
  err "  tfvars:    $TFVARS_CLUSTER"
  err "  AWS:       $CLUSTER_ROLE"
  NEEDS_FIX=1
elif [ -n "$TFVARS_NODE" ] && [ "$TFVARS_NODE" != "$NODE_ROLE" ]; then
  err "node_role_name in $TFVARS_FILE does NOT match the role in this account."
  err "  tfvars:    $TFVARS_NODE"
  err "  AWS:       $NODE_ROLE"
  NEEDS_FIX=1
fi

if [ "$NEEDS_FIX" -ne 0 ]; then
  echo
  warn "Update $TFVARS_FILE so the values match the AWS account:"
  echo
  cat <<EOF
cluster_role_name = "$CLUSTER_ROLE"
node_role_name    = "$NODE_ROLE"
EOF
  echo
  warn "Then re-run 'terraform plan' to confirm."
  exit 4
fi

ok "All checks passed. You can run:"
ok "    terraform init"
ok "    terraform plan"
ok "    terraform apply"

exit 0
