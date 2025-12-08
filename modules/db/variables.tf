variable "db_name" { type = string }
variable "username" { type = string }
variable "password" { type = string }
variable "engine" {
  type    = string
  default = "mysql"
}
variable "engine_version" {
  type    = string
  default = "8.0"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "subnet_ids" { type = list(string) }
variable "vpc_security_group_ids" { type = list(string) }
