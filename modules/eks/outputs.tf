# ============================================================
# Outputs — EKS Module
# ============================================================

output "cluster_id" {
  description = "ID EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "ARN EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_name" {
  description = "Nama EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint API server EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Certificate authority data untuk kubeconfig"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Versi Kubernetes cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "ID security group cluster"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "ID security group node group"
  value       = aws_security_group.node.id
}

output "node_group_arn" {
  description = "ARN node group"
  value       = aws_eks_node_group.this.arn
}

output "node_group_id" {
  description = "ID node group"
  value       = aws_eks_node_group.this.id
}

output "oidc_provider_arn" {
  description = "ARN OIDC provider untuk IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL OIDC provider untuk IRSA"
  value       = aws_iam_openid_connect_provider.eks.url
}

output "cluster_iam_role_arn" {
  description = "ARN IAM role untuk EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "ARN IAM role untuk node group"
  value       = aws_iam_role.node.arn
}

output "node_iam_role_name" {
  description = "Nama IAM role untuk node group"
  value       = aws_iam_role.node.name
}

output "alb_controller_iam_role_arn" {
  description = "ARN IAM role untuk AWS Load Balancer Controller (IRSA)"
  value       = aws_iam_role.alb_controller.arn
}
