terraform {
  required_version = ">= 1.5.0"
  backend "local" {} # ganti ke s3 backend saat siap
}

provider "aws" {
  region = "ap-southeast-1"
}

module "vpc" {
  source   = "../../modules/vpc"
  vpc_cidr = "10.0.0.0/16"
  azs      = ["ap-southeast-1a", "ap-southeast-1b"]
}
