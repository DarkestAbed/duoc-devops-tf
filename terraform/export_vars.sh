#!/bin/bash

# ==============================================================================
# AWS Academy Credentials
# Copy the values from AWS Details > Learner Lab, then source this file:
#   source 00-export_vars.sh
# ==============================================================================

export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_SESSION_TOKEN=""

# After terraform apply, connect to the cluster with:
#   aws eks update-kubeconfig --region us-east-1 --name tienda-eks
#
# Authenticate Docker with ECR:
#   aws ecr get-login-password --region us-east-1 \
#     | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
