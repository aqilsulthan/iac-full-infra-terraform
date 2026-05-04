# ============================================================
# ECR Module — Variables
# ============================================================

variable "repository_name" {
  description = "Nama ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Mutabilitas tag image (MUTABLE atau IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Scan image otomatis saat push"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags yang akan diterapkan ke ECR repository"
  type        = map(string)
  default     = {}
}
