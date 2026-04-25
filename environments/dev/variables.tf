# ============================================================
# Environment Variables — Dev
# ============================================================

# ---- AWS Provider ----
variable "aws_region" {
  description = "AWS region untuk deployment"
  type        = string
  default     = "ap-southeast-1"
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
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
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

# ---- S3 Backend ----
variable "state_bucket" {
  description = "Nama S3 bucket untuk Terraform state"
  type        = string
  default     = "iac-portfolio-tfstate-aqilsulthan-2025"
}

variable "state_key" {
  description = "Path key untuk state file di S3"
  type        = string
  default     = "dev/terraform.tfstate"
}

variable "state_dynamodb_table" {
  description = "Nama DynamoDB table untuk state locking"
  type        = string
  default     = "terraform-locks"
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
