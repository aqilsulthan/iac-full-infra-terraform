resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "app-db-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "app_db" {
  identifier              = "app-db"
  allocated_storage       = 20
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids  = var.vpc_security_group_ids
  db_name                 = var.db_name
  username                = var.username
  password                = var.password

  publicly_accessible     = false
  skip_final_snapshot     = true
}