# ============================================================
# Dev Environment Variables
# ============================================================

# ---- AWS Provider ----
aws_region = "ap-southeast-3"

# ---- VPC ----
vpc_cidr           = "10.0.0.0/16"
azs                = ["ap-southeast-3a", "ap-southeast-3b"]
enable_nat_gateway = false

# ---- EC2 / Compute ----
instance_type  = "t3.micro"
instance_count = 2

# ---- Auto Scaling Group ----
enable_asg           = true
asg_desired_capacity = 2
asg_min_size         = 2
asg_max_size         = 4
asg_app_name         = "app"

# ---- Scaling Policy & Alarm ----
scale_out_adjustment        = 1
scale_out_cooldown          = 60
cpu_high_threshold          = 70
cpu_high_evaluation_periods = 2
cpu_high_period             = 60

# ---- Security Group ----
# ═══════════════════════════════════════════════════════
# 🔐 ISI IP KAMU DISINI
# Cara cari IP sendiri: buka https://whatismyip.com
# lalu tulis: "<IP_KAMU>/32"
# Contoh: app_ingress_cidr_blocks = ["123.123.123.123/32"]
# ═══════════════════════════════════════════════════════
# ⚠️  Saat ini: 0.0.0.0/0 = TERBUKA UNTUK SEMUA
#    Ganti sebelum staging/prod!
app_ingress_cidr_blocks = ["36.71.225.181/32"] # my ip
app_sg_name             = "app-sg"
db_sg_name              = "db-sg"

# ---- Database ----
db_name     = "appdb"
db_username = "appuser"

# Password: di-inject via TF_VAR_db_password (GitHub Secret di CI, atau env var lokal)
# db_password = "..." ← JANGAN commit password ke repo!

# ---- Secrets Manager ----
db_secret_name = "dev-db-credentials"

# ---- S3 Backend ----
state_bucket         = "iac-tfstate-407772390483"
state_key            = "dev/terraform.tfstate"
state_dynamodb_table = "terraform-locks"

# ---- Tags ----
environment  = "dev"
project_name = "iac-full-infra"
