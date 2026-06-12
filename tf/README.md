# AWS Academy 3-Tier Infrastructure (Terraform)

Modular Terraform configuration that deploys a standard **3-tier VPC architecture** across two Availability Zones on AWS. It provisions a Web (Bastion), Application, and Data layer using EC2 instances, with strict **Security Group chaining** to enforce traffic flow.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Module Structure](#module-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Module Reference](#module-reference)
  - [`network`](#network)
  - [`security_groups`](#security_groups)
  - [`compute`](#compute)
- [Security Architecture](#security-architecture)
- [Outputs](#outputs)
- [Troubleshooting](#troubleshooting)
  - [Cannot SSH into the bastion (ec2-web)](#cannot-ssh-into-the-bastion-ec2-web)
  - [EC2 Instance Connect fails](#ec2-instance-connect-fails)
  - [Terraform plan shows everything being recreated](#terraform-plan-shows-everything-being-recreated)
- [Ansible Integration](#ansible-integration)

---

## Architecture Overview

```
Internet
    |
    v
+----------------------------------+
|  Public Subnet (10.0.0.0/24)     |
|  ec2-web (Bastion + Nginx)       |
|  Elastic IP + SG: web-sg         |
+----------------------------------+
           | SSH (22)
           | HTTP (80)
           v
+----------------------------------+
|  Private App Subnet (10.0.2.0/24)|
|  ec2-app (NodeJS Backend)        |
|  SG: app-sg (only from web-sg)   |
+----------------------------------+
           | MySQL (3306)
           v
+----------------------------------+
|  Private Data Subnet (10.0.4.0/24)|
|  ec2-datos (MySQL)                |
|  SG: datos-sg (only from app-sg)  |
+----------------------------------+
```

- **VPC CIDR:** `10.0.0.0/20` (4,096 IPs)
- **AZs:** `us-east-1a`, `us-east-1b`
- **NAT Gateway:** Single NAT in the first public subnet (cost-optimized for labs)
- **S3 Endpoint:** Gateway VPC endpoint to access S3 without traversing the NAT

---

## Module Structure

```
tf/
├── main.tf                  # Orchestrates modules + state migration (moved blocks)
├── variables.tf             # Root-level variables
├── outputs.tf               # Root-level outputs
├── 00-versions.tf           # Terraform + AWS provider config
├── terraform.tfvars.example   # Example variable values
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security_groups/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── compute/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── README.md
```

### Why modules?

- **Isolation:** Each layer (network, security, compute) can be validated, tested, and versioned independently.
- **Reusability:** The `network` module can be dropped into any other project needing a 3-tier VPC.
- **Clarity:** Root `main.tf` reads like a wiring diagram — you see *what* is deployed without drowning in *how*.

---

## Prerequisites

1. **Terraform >= 1.0** installed.
2. **AWS CLI** configured, or the following env vars exported:
   ```bash
   export AWS_ACCESS_KEY_ID="..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_SESSION_TOKEN="..."
   ```
3. **An existing EC2 Key Pair** in the target AWS region.
   - In AWS Academy this is usually provided as a `.pem` file (e.g., `labsuser.pem`).
   - You must **import the public key** into AWS EC2 > Key Pairs and note the **Key Pair Name**.
   - SSH will **fail** if this step is skipped.

---

## Quick Start

```bash
cd tf/

# 1. (Optional) copy the example vars and edit
cp terraform.tfvars.example terraform.tfvars
# vim terraform.tfvars   <-- set key_name = "your-key-name"

# 2. Initialize
terraform init

# 3. Review the plan
terraform plan -var="key_name=your-key-name"

# 4. Apply
terraform apply -var="key_name=your-key-name"
```

After a successful apply, Terraform prints the public and private IPs needed for Ansible:

```
web_eip_public_ip       = "32.199.8.252"
web_instance_private_ip = "10.0.0.19"
app_instance_private_ip = "10.0.2.201"
datos_instance_private_ip = "10.0.4.132"
```

---

## Module Reference

### `network`

Provisions the VPC, subnets, gateways, route tables, and the S3 VPC endpoint.

| Input | Type | Default | Description |
|---|---|---|---|
| `vpc_cidr` | `string` | `"10.0.0.0/20"` | CIDR block for the VPC |
| `azs` | `list(string)` | `["us-east-1a", "us-east-1b"]` | Availability Zones |
| `public_subnet_newbits` | `number` | `4` | Additional bits for subnetting |
| `public_subnet_offset` | `number` | `0` | CIDR offset for public subnets |
| `private_app_subnet_offset` | `number` | `2` | CIDR offset for app subnets |
| `private_data_subnet_offset` | `number` | `4` | CIDR offset for data subnets |
| `map_public_ip_on_launch` | `bool` | `true` | Auto-assign public IPs in public subnets |
| `enable_dns_support` | `bool` | `true` | Enable VPC DNS resolution |
| `enable_dns_hostnames` | `bool` | `true` | Enable DNS hostnames |
| `enable_s3_endpoint` | `bool` | `true` | Create S3 Gateway endpoint |
| `tags` | `map(string)` | `{}` | Common tags |

| Output | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | List of public subnet IDs |
| `private_app_subnet_ids` | List of private app subnet IDs |
| `private_data_subnet_ids` | List of private data subnet IDs |
| `igw_id` | Internet Gateway ID |
| `nat_gateway_id` | NAT Gateway ID |
| `public_route_table_id` | Public route table ID |
| `private_route_table_id` | Private route table ID |

### `security_groups`

Creates three security groups with chained ingress rules.

| Input | Type | Default | Description |
|---|---|---|---|
| `vpc_id` | `string` | (required) | VPC to create SGs in |
| `allowed_web_cidr` | `string` | `"0.0.0.0/0"` | CIDR allowed to reach web tier |
| `tags` | `map(string)` | `{}` | Common tags |

| Output | Description |
|---|---|
| `sg_web_id` | Web security group ID |
| `sg_app_id` | App security group ID |
| `sg_datos_id` | Data security group ID |

**Rule Summary:**

| SG | Ingress From | Ports | Purpose |
|---|---|---|---|
| `web-sg` | `0.0.0.0/0` | 22, 80, ICMP | Bastion + Nginx frontend |
| `app-sg` | `web-sg` | 22, 3001, ICMP | NodeJS backend (from web only) |
| `datos-sg` | `app-sg` | 3306, ICMP | MySQL (from app only) |
| `datos-sg` | `web-sg` | 22 | SSH from bastion for Ansible |

### `compute`

Launches the 3 EC2 instances, attaches IAM profiles, EIPs, and optional user-data.

| Input | Type | Default | Description |
|---|---|---|---|
| `ami_id` | `string` | `""` | Custom AMI (empty = latest AL2023) |
| `instance_type` | `string` | `"t3.micro"` | EC2 instance type |
| `key_name` | `string` | (required) | EC2 Key Pair name |
| `iam_role_name` | `string` | `"LabRole"` | Pre-existing IAM role |
| `web_subnet_id` | `string` | (required) | Subnet for web instance |
| `app_subnet_id` | `string` | (required) | Subnet for app instance |
| `datos_subnet_id` | `string` | (required) | Subnet for datos instance |
| `sg_web_id` | `string` | (required) | Web SG ID |
| `sg_app_id` | `string` | (required) | App SG ID |
| `sg_datos_id` | `string` | (required) | Data SG ID |
| `user_data_web` | `string` | `""` | Bootstrap script for web |
| `user_data_app` | `string` | `""` | Bootstrap script for app |
| `user_data_datos` | `string` | `""` | Bootstrap script for datos |
| `tags` | `map(string)` | `{}` | Common tags |

| Output | Description |
|---|---|
| `web_instance_id` | Web EC2 instance ID |
| `web_instance_private_ip` | Web private IP |
| `web_eip_public_ip` | Web Elastic IP (public) |
| `app_instance_id` | App EC2 instance ID |
| `app_instance_private_ip` | App private IP |
| `datos_instance_id` | Datos EC2 instance ID |
| `datos_instance_private_ip` | Datos private IP |
| `instance_profile_name` | IAM instance profile name |
| `ami_id_used` | Resolved AMI ID |

---

## Security Architecture

Traffic is explicitly **layered**:

1. **Internet -> Web (`sg_web`)**
   - Only ports 22 (SSH), 80 (HTTP), and ICMP are open.
2. **Web -> App (`sg_app`)**
   - SSH is restricted to the web security group (no direct internet SSH).
   - Port 3001 (NodeJS API) is only reachable from the web tier.
3. **App -> Data (`sg_datos`)**
   - MySQL (3306) is only reachable from the app tier.
   - SSH from the web tier is allowed for Ansible bastion jumps.

This pattern ensures that even if one layer is compromised, lateral movement to deeper layers is blocked by SG rules.

---

## Outputs

The root module exposes the same outputs as the original flat configuration, so existing Ansible inventory files and scripts continue to work:

| Output | Example | Use |
|---|---|---|
| `web_eip_public_ip` | `32.199.8.252` | SSH into bastion |
| `web_instance_private_ip` | `10.0.0.19` | Internal routing |
| `app_instance_private_ip` | `10.0.2.201` | Backend target IP |
| `datos_instance_private_ip` | `10.0.4.132` | DB target IP |

---

## Troubleshooting

### Cannot SSH into the bastion (ec2-web)

**Symptom:** `ssh -i labsuser.pem ec2-user@<EIP>` times out or gets `Permission denied`.

**Root cause #1: No key pair attached**
The `terraform.tfstate` showed `"key_name": ""` for all instances. The original `variables.tf` defaulted `key_name` to an empty string. If you run `terraform apply` without setting `key_name`, the instances launch **without any SSH key**. PEM-based authentication is then impossible.

**Fix:**
1. Go to **AWS EC2 > Key Pairs** and create or import a key pair. Note its **Name**.
2. Pass it to Terraform:
   ```bash
   terraform apply -var="key_name=labsuser"
   ```
3. Ensure your `.pem` file permissions are strict:
   ```bash
   chmod 400 labsuser.pem
   ```
4. Connect:
   ```bash
   ssh -i labsuser.pem ec2-user@<web_eip_public_ip>
   ```

**Root cause #2: Wrong username**
Amazon Linux 2023 uses `ec2-user`, not `ubuntu`, `root`, or `admin`.

**Root cause #3: Using the auto-assigned public IP instead of the Elastic IP**
The instance gets a transient public IP on launch, but an **Elastic IP** (`32.199.8.252`) is attached afterwards. Always use the Elastic IP from `terraform output`.

---

### EC2 Instance Connect fails

**Symptom:** Clicking "Connect" in the AWS console (browser-based SSH) fails.

**Why:** AWS Academy student IAM roles often **lack** the `ec2-instance-connect:SendSSHPublicKey` permission. The EC2 Instance Connect service is a console-side IAM operation. Without that permission, the console cannot inject a temporary key into the instance, even though the instance itself is perfectly reachable.

**Alternatives:**
1. **Use standard SSH with a PEM key** (see above). This does not depend on Instance Connect IAM permissions.
2. **Use AWS Systems Manager Session Manager** (if the `LabRole` includes `AmazonSSMManagedInstanceCore`). This requires the SSM agent (pre-installed on AL2023) and outbound HTTPS to the SSM service.

---

### Terraform plan shows everything being recreated

If you see `Plan: 18 to add, 18 to destroy` after the refactor, the `moved` blocks in `main.tf` did not work. Common causes:

1. **State file was deleted or you ran `terraform init` in a new folder.**
   - The `moved` blocks only help if the existing `terraform.tfstate` is present.
   - Ensure you are in the original `tf/` directory where `terraform.tfstate` lives.
2. **Old `.tf` files were not removed.**
   - If `01-network.tf`, `02-compute.tf`, or `03-outputs.tf` still exist alongside the new modules, Terraform sees duplicates.
   - They have been removed in this refactor, but double-check:
     ```bash
     ls tf/*.tf
     ```
3. **Resource addresses in `moved` blocks are wrong.**
   - If a resource was renamed inside a module, the `moved` block must match the **new** module-local address.
   - Check `terraform state list` to verify current addresses.

If the state migration fails and you are in a lab environment, the safest recovery is:
```bash
terraform destroy -var="key_name=..."
terraform apply -var="key_name=..."
```

---

## Ansible Integration

After `terraform apply`, copy the printed IPs into `ansible/inventory.ini`:

```ini
[web]
ec2-web ansible_host=10.0.0.19

[app]
ec2-app ansible_host=10.0.2.201

[datos]
ec2-datos ansible_host=10.0.4.132

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=~/setup/my-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

Then run the playbooks in order:

```bash
# 1. Bootstrap Docker + Git
ansible-playbook -i ansible/inventory.ini ansible/setup.yml

# 2. Clone project code
ansible-playbook -i ansible/inventory.ini ansible/deploy.yml

# 3. Deploy containers across tiers
ansible-playbook -i ansible/inventory.ini ansible/deploy_apps.yml
```

> **Tip:** If you added `user_data` to the instances, step 1 may be partially or fully unnecessary because Docker and Git will already be installed on first boot.
