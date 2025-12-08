variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "user_data" {
  type = string
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "instance_profile" {
  description = "Name or ARN of the IAM instance profile to attach to instances. Empty string = no profile attached."
  type        = string
  default     = ""
}