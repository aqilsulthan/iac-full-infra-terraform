variable "secret_name" { type = string }
variable "secret_string" { type = string }
variable "recovery_window_in_days" {
  description = "Jumlah hari secret disimpan sebelum dihapus permanen. Set ke 0 untuk menghapus langsung (berguna di Dev)."
  type        = number
  default     = 0
}