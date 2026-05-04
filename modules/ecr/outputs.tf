# ============================================================
# ECR Module — Outputs
# ============================================================

output "repository_url" {
  description = "URL ECR repository (format: <account_id>.dkr.ecr.<region>.amazonaws.com/<name>)"
  value       = aws_ecr_repository.repo.repository_url
}

output "repository_arn" {
  description = "ARN ECR repository"
  value       = aws_ecr_repository.repo.arn
}

output "registry_id" {
  description = "AWS account ID pemilik registry"
  value       = aws_ecr_repository.repo.registry_id
}

output "repository_name" {
  description = "Nama ECR repository"
  value       = aws_ecr_repository.repo.name
}
