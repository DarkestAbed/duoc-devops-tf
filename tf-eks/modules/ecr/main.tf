# ==============================================================================
# ECR MODULE
# Creates Elastic Container Registry repositories for the Tienda application.
# ==============================================================================

resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.repository_names)
  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = each.value
  })
}