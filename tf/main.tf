# ==============================================================================
# ROOT MODULE
# Orchestrates network, security groups, and compute modules.
# ==============================================================================

module "network" {
  source = "./modules/network"

  vpc_cidr = var.vpc_cidr
  azs      = var.azs
  tags     = var.common_tags
}

module "security_groups" {
  source = "./modules/security_groups"

  vpc_id           = module.network.vpc_id
  allowed_web_cidr = var.allowed_web_cidr
  tags             = var.common_tags
}

module "compute" {
  source = "./modules/compute"

  ami_id        = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  iam_role_name = var.iam_role_name

  web_subnet_id   = module.network.public_subnet_ids[0]
  app_subnet_id   = module.network.private_app_subnet_ids[0]
  datos_subnet_id = module.network.private_data_subnet_ids[0]

  sg_web_id   = module.security_groups.sg_web_id
  sg_app_id   = module.security_groups.sg_app_id
  sg_datos_id = module.security_groups.sg_datos_id

  user_data_web   = var.user_data_web
  user_data_app   = var.user_data_app
  user_data_datos = var.user_data_datos

  tags = var.common_tags
}

# ==============================================================================
# MOVED BLOCKS
# These tell Terraform that the existing state-managed resources have been
# relocated into modules. Without these, Terraform would plan to destroy and
# recreate all infrastructure.
# ==============================================================================

# --- Network ---
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_subnet.public[0]
  to   = module.network.aws_subnet.public[0]
}

moved {
  from = aws_subnet.public[1]
  to   = module.network.aws_subnet.public[1]
}

moved {
  from = aws_subnet.private_app[0]
  to   = module.network.aws_subnet.private_app[0]
}

moved {
  from = aws_subnet.private_app[1]
  to   = module.network.aws_subnet.private_app[1]
}

moved {
  from = aws_subnet.private_data[0]
  to   = module.network.aws_subnet.private_data[0]
}

moved {
  from = aws_subnet.private_data[1]
  to   = module.network.aws_subnet.private_data[1]
}

moved {
  from = aws_internet_gateway.igw
  to   = module.network.aws_internet_gateway.igw
}

moved {
  from = aws_eip.nat_eip
  to   = module.network.aws_eip.nat_eip
}

moved {
  from = aws_nat_gateway.nat
  to   = module.network.aws_nat_gateway.nat
}

moved {
  from = aws_route_table.public_rt
  to   = module.network.aws_route_table.public_rt
}

moved {
  from = aws_route_table.private_rt
  to   = module.network.aws_route_table.private_rt
}

moved {
  from = aws_route_table_association.public_assoc[0]
  to   = module.network.aws_route_table_association.public_assoc[0]
}

moved {
  from = aws_route_table_association.public_assoc[1]
  to   = module.network.aws_route_table_association.public_assoc[1]
}

moved {
  from = aws_route_table_association.app_assoc[0]
  to   = module.network.aws_route_table_association.app_assoc[0]
}

moved {
  from = aws_route_table_association.app_assoc[1]
  to   = module.network.aws_route_table_association.app_assoc[1]
}

moved {
  from = aws_route_table_association.data_assoc[0]
  to   = module.network.aws_route_table_association.data_assoc[0]
}

moved {
  from = aws_route_table_association.data_assoc[1]
  to   = module.network.aws_route_table_association.data_assoc[1]
}

moved {
  from = aws_vpc_endpoint.s3
  to   = module.network.aws_vpc_endpoint.s3
}

# --- Security Groups ---
moved {
  from = aws_security_group.sg_web
  to   = module.security_groups.aws_security_group.sg_web
}

moved {
  from = aws_security_group.sg_app
  to   = module.security_groups.aws_security_group.sg_app
}

moved {
  from = aws_security_group.sg_datos
  to   = module.security_groups.aws_security_group.sg_datos
}

# --- Compute ---
moved {
  from = aws_iam_instance_profile.lab_profile
  to   = module.compute.aws_iam_instance_profile.lab_profile
}

moved {
  from = aws_instance.ec2_web
  to   = module.compute.aws_instance.ec2_web
}

moved {
  from = aws_eip.web_eip
  to   = module.compute.aws_eip.web_eip
}

moved {
  from = aws_instance.ec2_app
  to   = module.compute.aws_instance.ec2_app
}

moved {
  from = aws_instance.ec2_datos
  to   = module.compute.aws_instance.ec2_datos
}
