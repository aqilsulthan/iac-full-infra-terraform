# terraform {
#   required_version = ">= 1.5.0"
#   backend "local" {} # ganti ke s3 backend saat siap
# }

terraform {
  backend "s3" {
    bucket         = "iac-portfolio-tfstate-aqilsulthan-2025"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

module "vpc" {
  source   = "../../modules/vpc"
  vpc_cidr = "10.0.0.0/16"
  azs      = ["ap-southeast-1a", "ap-southeast-1b"]
}

# Security group for app
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # sementara untuk pengujian
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "ec2" {
  source              = "../../modules/ec2"
  ami_id              = "ami-0f42f6c9953c7b4b5" # Ubuntu 22.04 - region ap-southeast-1
  instance_type       = "t3.micro"
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_ids  = [aws_security_group.app_sg.id]
  user_data           = file("${path.module}/../../scripts/bootstrap.sh")
  instance_count      = 2
  instance_profile    = module.iam.instance_profile
}

module "alb" {
  source             = "../../modules/alb"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  target_instance_ids = module.ec2.instance_ids
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "db_secret" {
  source        = "../../modules/secrets"
  secret_name   = "db-credentials"
  secret_string = jsonencode({
    username = "appuser"
    password = "apppassword123"
  })
}

module "db" {
  source                  = "../../modules/db"
  db_name                 = "appdb"
  username                = "appuser"
  password                = "apppassword123"
  subnet_ids              = module.vpc.public_subnet_ids
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
}

module "iam" {
  source = "../../modules/iam"
}




