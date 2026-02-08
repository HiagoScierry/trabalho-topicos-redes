resource "aws_db_subnet_group" "main" {
  name       = var.subnet_group_name
  subnet_ids = var.subnet_ids

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "main" {
  identifier              = "microservices-db"
  allocated_storage       = 20
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  username                = var.db_username
  password                = var.db_password
  port                    = var.db_port
  db_name                 = var.db_name
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = var.security_group_ids
  publicly_accessible     = var.publicly_accessible
  skip_final_snapshot     = true
}

variable "vpc_id" {}
variable "subnet_ids" {}
variable "db_username" {
  type = string
}
variable "db_password" {
  type = string
}
variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "publicly_accessible" {
  type    = bool
  default = false
}

variable "subnet_group_name" {
  type    = string
  default = "main-db-subnet-group"
}

output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "rds_host" {
  value = aws_db_instance.main.address
}
