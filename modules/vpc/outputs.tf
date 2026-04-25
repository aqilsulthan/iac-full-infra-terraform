output "vpc_id" {
  description = "ID VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List ID public subnet"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List ID private subnet"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID NAT Gateway (leave empty if disabled)"
  value       = try(aws_nat_gateway.this[0].id, null)
}

output "nat_public_ip" {
  description = "Public IP NAT Gateway (leave empty if disabled)"
  value       = try(aws_eip.nat[0].public_ip, null)
}
