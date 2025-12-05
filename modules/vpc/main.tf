variable "vpc_cidr" { type = string }
variable "azs"     { type = list(string) }

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "iac-demo-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
  }
}
