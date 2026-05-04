# ============================================================
# Outputs — Dev Environment
# ============================================================

# ---- Network ----
output "vpc_id" {
  description = "ID VPC yang dibuat"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List ID public subnet"
  value       = module.vpc.public_subnet_ids
}

# ---- Load Balancer ----
output "alb_dns_name" {
  description = "DNS name ALB — akses aplikasi via URL ini"
  value       = module.alb.dns_name
}

output "alb_target_group_arn" {
  description = "ARN target group ALB"
  value       = module.alb.target_group_arn
}

# ---- Compute (EC2 langsung, jika ASG nonaktif) ----
output "ec2_instance_ids" {
  description = "ID EC2 instance (kosong jika ASG aktif)"
  value       = var.enable_asg ? [] : try(module.ec2[0].instance_ids, [])
}

output "ec2_private_ips" {
  description = "Private IP EC2 instance (kosong jika ASG aktif)"
  value       = var.enable_asg ? [] : try(module.ec2[0].private_ips, [])
}

# ---- Auto Scaling Group ----
output "asg_name" {
  description = "Nama Auto Scaling Group (kosong jika nonaktif)"
  value       = var.enable_asg ? try(module.asg[0].asg_name, "") : ""
}

# ---- Database ----
output "db_endpoint" {
  description = "Endpoint koneksi database (host:port)"
  value       = module.db.endpoint
}

output "db_name" {
  description = "Nama database"
  value       = var.db_name
}

# ---- ECR ----
output "ecr_repository_url" {
  description = "URL ECR repository untuk push/pull Docker image"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN ECR repository"
  value       = module.ecr.repository_arn
}

output "ecr_repository_name" {
  description = "Nama ECR repository"
  value       = module.ecr.repository_name
}

# ---- EKS (Kubernetes) ----
output "eks_cluster_name" {
  description = "Nama EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint API server EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Versi Kubernetes yang berjalan di EKS"
  value       = module.eks.cluster_version
}

output "eks_node_security_group_id" {
  description = "ID security group untuk node group EKS"
  value       = module.eks.node_security_group_id
}

output "eks_node_group_id" {
  description = "ID node group EKS"
  value       = module.eks.node_group_id
}

output "eks_oidc_provider_arn" {
  description = "ARN OIDC provider untuk IRSA di EKS"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  description = "URL OIDC provider EKS"
  value       = module.eks.oidc_provider_url
}

output "eks_alb_controller_iam_role_arn" {
  description = "ARN IAM role untuk AWS Load Balancer Controller (IRSA)"
  value       = module.eks.alb_controller_iam_role_arn
}

# ---- Command Reference ----
output "connect_commands" {
  description = "Perintah untuk mengakses resource"
  sensitive   = true
  value = {
    curl_app              = "curl http://${module.alb.dns_name}"
    mysql_cli             = "mysql -h ${module.db.endpoint} -u ${var.db_username} -p"
    eks_update_kubeconfig = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
    kubectl_get_nodes     = "kubectl get nodes"
    kubectl_get_pods      = "kubectl get pods -n app"
  }
}

# ---- IAM ----
output "iam_instance_profile" {

  description = "Nama instance profile IAM yang terattach ke EC2/ASG"
  value       = module.iam.instance_profile
}

# ---- Environment Info ----
output "environment" {
  description = "Nama environment"
  value       = var.environment
}

output "aws_region" {
  description = "Region tempat resource dideploy"
  value       = var.aws_region
}
