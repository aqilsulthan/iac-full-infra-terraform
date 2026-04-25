variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "target_instance_ids" { type = list(string) }

variable "tags" {
  description = "Tags tambahan untuk semua resource ALB"
  type        = map(string)
  default     = {}
}