# ============================================================
# ECR (Elastic Container Registry) Module
# ============================================================
# Menyediakan ECR repository untuk menyimpan Docker image.

resource "aws_ecr_repository" "repo" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = var.tags
}

# Lifecycle policy: hapus image lama secara otomatis
resource "aws_ecr_lifecycle_policy" "lifecycle" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
