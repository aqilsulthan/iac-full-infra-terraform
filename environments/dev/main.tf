terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket       = "iac-tfstate-407772390483"
    key          = "dev/terraform.tfstate"
    region       = "ap-southeast-3"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ---- Common Tags (applied to all resources) ----
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  bootstrap_user_data = replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(file("${path.module}/../../scripts/bootstrap.sh"), "__APP_NAME__", var.project_name),
              "__AWS_REGION__", var.aws_region
            ),
            "__DB_HOST__", module.db.endpoint
          ),
          "__DB_NAME__", var.db_name
        ),
        "__DB_SECRET_NAME__", var.db_secret_name
      ),
      "__ENVIRONMENT__", var.environment
    ),
    "__PROJECT_NAME__", var.project_name
  )
}

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.common_tags
}

# Security group for app
resource "aws_security_group" "app_sg" {
  name   = var.app_sg_name
  vpc_id = module.vpc.vpc_id

  # Allow traffic from user IP (direct admin access)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.app_ingress_cidr_blocks
  }

  # Allow traffic from ALB in VPC (health checks + forwarding)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "ec2" {
  count              = var.enable_asg ? 0 : 1
  source             = "../../modules/ec2"
  ami_id             = data.aws_ami.ubuntu_2204.id
  instance_type      = var.instance_type
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [aws_security_group.app_sg.id]
  user_data          = local.bootstrap_user_data
  instance_count     = var.instance_count
  instance_profile   = module.iam.instance_profile
  tags               = local.common_tags
}

module "alb" {
  source              = "../../modules/alb"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  target_instance_ids = var.enable_asg ? [] : module.ec2[0].instance_ids
  tags                = local.common_tags
  depends_on          = [module.vpc]
}

resource "aws_security_group" "db_sg" {
  name   = var.db_sg_name
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Buat secret di AWS Secrets Manager
module "db_secret" {
  source      = "../../modules/secrets"
  secret_name = var.db_secret_name
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# Baca secret dari AWS Secrets Manager (runtime, bukan hardcode)
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id  = module.db_secret.secret_arn
  depends_on = [module.db_secret]
}

# Parse JSON secret ke local values
locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.db_creds.secret_string
  )
}

module "db" {
  source                 = "../../modules/db"
  db_name                = var.db_name
  username               = local.db_creds.username
  password               = local.db_creds.password
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  tags                   = local.common_tags
}

module "iam" {
  source = "../../modules/iam"
  tags   = local.common_tags
}

module "asg" {
  count = var.enable_asg ? 1 : 0

  source = "../../modules/asg"

  name               = var.asg_app_name
  ami_id             = data.aws_ami.ubuntu_2204.id
  instance_type      = var.instance_type
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [aws_security_group.app_sg.id]
  instance_profile   = module.iam.instance_profile

  desired_capacity = var.asg_desired_capacity
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size

  user_data = local.bootstrap_user_data

  target_group_arns = [module.alb.target_group_arn]
  tags              = local.common_tags
}

resource "aws_autoscaling_policy" "scale_out" {
  count                  = var.enable_asg ? 1 : 0
  name                   = "scale-out"
  scaling_adjustment     = var.scale_out_adjustment
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.scale_out_cooldown
  autoscaling_group_name = module.asg[0].asg_name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = var.enable_asg ? 1 : 0
  alarm_name          = "cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_high_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cpu_high_period
  statistic           = "Average"
  threshold           = var.cpu_high_threshold

  dimensions = {
    AutoScalingGroupName = module.asg[0].asg_name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out[0].arn]
}


