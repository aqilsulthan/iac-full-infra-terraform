# ============================================================
# Environment Variables — Dev
# ============================================================

# ---- AWS Provider ----
variable "aws_region" {
  description = "AWS region untuk deployment"
  type        = string
  default     = "ap-southeast-3"
}

# ---- VPC ----
variable "vpc_cidr" {
  description = "CIDR block untuk VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones untuk deployment"
  type        = list(string)
  default     = ["ap-southeast-3a", "ap-southeast-3b"]
}

variable "enable_nat_gateway" {
  description = "Aktifkan NAT Gateway"
  type        = bool
  default     = false
}

# ---- EC2 / Compute ----
variable "instance_type" {
  description = "Instance type untuk EC2 dan ASG launch template"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Jumlah EC2 instance (digunakan jika ASG tidak aktif)"
  type        = number
  default     = 2
}

# ---- Auto Scaling Group ----
variable "enable_asg" {
  description = "Aktifkan Auto Scaling Group (jika true, EC2 module di-skip)"
  type        = bool
  default     = true
}

variable "asg_desired_capacity" {
  description = "Jumlah instance yang diinginkan di ASG"
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Jumlah minimum instance di ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Jumlah maksimum instance di ASG"
  type        = number
  default     = 4
}

variable "asg_app_name" {
  description = "Nama aplikasi untuk prefix resource ASG"
  type        = string
  default     = "app"
}

# ---- Autoscaling Policy & Alarm ----
variable "scale_out_adjustment" {
  description = "Jumlah instance yang ditambah saat scale-out"
  type        = number
  default     = 1
}

variable "scale_out_cooldown" {
  description = "Cooldown period dalam detik setelah scale-out"
  type        = number
  default     = 60
}

variable "cpu_high_threshold" {
  description = "Threshold CPU utilization untuk alarm scale-out (%)"
  type        = number
  default     = 70
}

variable "cpu_high_evaluation_periods" {
  description = "Jumlah periode evaluasi sebelum alarm trigger"
  type        = number
  default     = 2
}

variable "cpu_high_period" {
  description = "Periode evaluasi CPU dalam detik"
  type        = number
  default     = 60
}

# ---- Security Group ----
variable "app_ingress_cidr_blocks" {
  description = "CIDR blocks yang diizinkan mengakses port 80 (app)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_sg_name" {
  description = "Nama security group untuk aplikasi"
  type        = string
  default     = "app-sg"
}

variable "db_sg_name" {
  description = "Nama security group untuk database"
  type        = string
  default     = "db-sg"
}

# ---- Database ----
variable "db_name" {
  description = "Nama database yang akan dibuat"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Username untuk database"
  type        = string
  default     = "appuser"
  sensitive   = true
}

variable "db_password" {
  description = "Password untuk database (gunakan Secrets Manager di production)"
  type        = string
  sensitive   = true
}

# ---- Secrets Manager ----
variable "db_secret_name" {
  description = "Nama secret di AWS Secrets Manager untuk kredensial DB"
  type        = string
  default     = "dev-db-credentials"
}

# ---- ECR ----
variable "ecr_repository_name" {
  description = "Nama ECR repository untuk menyimpan Docker image"
  type        = string
  default     = "iac-full-infra-app"
}

# ---- EKS (Kubernetes) ----
variable "eks_cluster_name" {
  description = "Nama EKS cluster"
  type        = string
  default     = "iac-full-infra-eks"
}

variable "eks_cluster_version" {
  description = "Versi Kubernetes untuk EKS cluster"
  type        = string
  default     = "1.30"
}

variable "eks_cluster_endpoint_private_access" {
  description = "Aktifkan akses private ke EKS API endpoint"
  type        = bool
  default     = false
}

variable "eks_cluster_endpoint_public_access" {
  description = "Aktifkan akses public ke EKS API endpoint"
  type        = bool
  default     = true
}

variable "eks_node_group_instance_types" {
  description = "Instance types untuk EKS node group"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "eks_node_group_desired_size" {
  description = "Jumlah node yang diinginkan"
  type        = number
  default     = 2
}

variable "eks_node_group_min_size" {
  description = "Jumlah minimum node"
  type        = number
  default     = 1
}

variable "eks_node_group_max_size" {
  description = "Jumlah maksimum node"
  type        = number
  default     = 4
}

variable "eks_node_group_disk_size" {
  description = "Ukuran disk dalam GB untuk node group"
  type        = number
  default     = 20
}

# ---- Tags ----
variable "environment" {

  description = "Nama environment untuk tagging"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nama proyek untuk tagging"
  type        = string
  default     = "iac-full-infra"
}
