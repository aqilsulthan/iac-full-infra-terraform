variable "name" { type = string }

variable "ami_id" { type = string }

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_ids" { type = list(string) }

variable "security_group_ids" { type = list(string) }

variable "instance_profile" { type = string }

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "user_data" { type = string }

variable "target_group_arns" {
  type = list(string)
}
