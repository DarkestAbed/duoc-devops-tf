# EKS Cluster Infrastructure — Terraform

Provisions an Amazon EKS cluster on AWS Academy, reusing the VPC created by the `tf/` module.

## Prerequisites

### 1. VPC Infrastructure

The VPC must already exist (run `terraform apply` in `tf/` first).

### 2. IAM Role

AWS Academy provides a pre-existing **`LabRole`** that is used for both the EKS cluster and the node group. This role already trusts `eks.amazonaws.com` and `ec2.amazonaws.com`, so no manual IAM role creation is needed.

> If you see an error about `LabRole` not being found, check that your AWS Academy lab session is active (click **Start Lab** in Vocareum).

### 3. Tools

- AWS CLI, `kubectl`, and `terraform` must be installed locally.

## Quick Start

```bash
# 1. Set AWS credentials
source 00-export_vars.sh   # Fill in values from AWS Details first

# 2. Initialize Terraform
terraform init

# 3. Review the plan
terraform plan

# 4. Apply (takes ~20-30 minutes for EKS)
terraform apply

# 5. Connect kubectl
aws eks update-kubeconfig --region us-east-1 --name tienda-eks

# 6. Verify nodes
kubectl get nodes

# 7. Login to ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

## Architecture

```
                     ┌──────────────────────────────┐
                     │        EKS Control Plane     │
                     │   (managed by AWS, public +   │
                     │    private endpoint access)   │
                     └──────────┬───────────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
     ┌──────┴──────┐     ┌──────┴──────┐     ┌──────┴──────┐
     │  Public     │     │ Private App │     │Private Data │
     │  Subnet 1-2 │     │  Subnet 1-2 │     │ Subnet 1-2  │
     │  (ELB)      │     │  (Nodes)    │     │  (Nodes)     │
     └─────────────┘     └─────────────┘     └─────────────┘
            │                   │                   │
     ┌──────┴──────────────────┴───────────────────┘──────┐
     │              VPC (10.0.0.0/20)                     │
     │              academy-vpc                            │
     └────────────────────────────────────────────────────┘
```

## Resources Created

| Resource          | Description                                     |
|-------------------|-------------------------------------------------|
| EKS Cluster       | Kubernetes control plane (v1.30)                 |
| Node Group        | SPOT t3.large, 1-3 nodes                        |
| ECR Repos         | tienda-frontend, tienda-backend, tienda-db       |
| Security Groups   | Cluster SG + Nodes SG                            |
| CloudWatch Logs   | Control plane log group (30-day retention)       |
| EKS Add-ons       | VPC CNI, CloudWatch Observability, Metrics Server |
| Subnet Tags       | k8s cluster/elb tags for LoadBalancer provisioning |

## Important Notes

- **EKS creation takes 10-15 minutes.** The node group takes an additional 5-10 minutes.
- **AWS Academy credentials expire.** When they do, re-run `aws configure` and `source 00-export_vars.sh` with new values.
- **SPOT instances** may be interrupted. If node group creation fails, try changing `capacity_type` to `ON_DEMAND` in `terraform.tfvars`.
- **Subnet tags** are applied via `aws_ec2_tag` and will be removed when you run `terraform destroy`.
- **IAM Role:** Uses the pre-existing `LabRole` provided by AWS Academy. No manual role creation needed.

## Teardown

```bash
terraform destroy
```

This removes the EKS cluster, node group, ECR repos, security groups, and CloudWatch log group. It also removes the Kubernetes subnet tags. The VPC and EC2 infrastructure from `tf/` is **not** affected.