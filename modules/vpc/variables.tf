variable "vpc_cidr" {
  description = "CIDR block untuk VPC"
  type        = string
}

variable "azs" {
  description = "List Availability Zones"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Aktifkan NAT Gateway untuk private subnet"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags tambahan untuk semua resource VPC"
  type        = map(string)
  default     = {}
}
