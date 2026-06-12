data "aws_iam_role" "lab_role" {
  name = var.iam_role_name
}

resource "aws_iam_instance_profile" "lab_profile" {
  name_prefix = "LabRoleProfile-"
  role        = data.aws_iam_role.lab_role.name
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  ami = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
}

resource "aws_instance" "ec2_web" {
  ami                    = local.ami
  instance_type          = var.instance_type
  subnet_id              = var.web_subnet_id
  vpc_security_group_ids = [var.sg_web_id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  key_name               = var.key_name
  user_data              = var.user_data_web != "" ? var.user_data_web : null

  tags = merge(var.tags, {
    Name = "ec2-web"
  })
}

resource "aws_eip" "web_eip" {
  instance   = aws_instance.ec2_web.id
  domain     = "vpc"
  depends_on = [aws_instance.ec2_web]
}

resource "aws_instance" "ec2_app" {
  ami                    = local.ami
  instance_type          = var.instance_type
  subnet_id              = var.app_subnet_id
  vpc_security_group_ids = [var.sg_app_id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  key_name               = var.key_name
  user_data              = var.user_data_app != "" ? var.user_data_app : null

  tags = merge(var.tags, {
    Name = "ec2-app"
  })
}

resource "aws_instance" "ec2_datos" {
  ami                    = local.ami
  instance_type          = var.instance_type
  subnet_id              = var.datos_subnet_id
  vpc_security_group_ids = [var.sg_datos_id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  key_name               = var.key_name
  user_data              = var.user_data_datos != "" ? var.user_data_datos : null

  tags = merge(var.tags, {
    Name = "ec2-datos"
  })
}
