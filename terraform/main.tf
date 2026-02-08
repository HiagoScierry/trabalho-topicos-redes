terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.region
}

locals {
  service_paths = {
    auth  = "/auth"
    user  = "/user"
    venda = "/venda"
  }
}

module "vpc" {
  source = "./modules/vpc"
}

resource "aws_ecs_cluster" "main" {
  name = "trabalho-cluster"
}

resource "aws_security_group" "alb" {
  name        = "trabalho-alb-sg"
  description = "Allow HTTP ingress to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Inbound HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "services" {
  name        = "trabalho-services-sg"
  description = "Allow traffic from ALB to ECS services"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "trabalho-db-sg"
  description = "Permite acessos controlados ao RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL das tasks ECS"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.services.id]
  }

  dynamic "ingress" {
    for_each = var.db_admin_cidrs
    content {
      description = "MySQL acesso administrativo"
      from_port   = var.db_port
      to_port     = var.db_port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  name               = "trabalho-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Path not found"
      status_code  = "404"
    }
  }
}

module "rds" {
  source              = "./modules/rds"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnet_ids
  db_username         = var.db_username
  db_password         = var.db_password
  db_port             = var.db_port
  db_name             = var.db_name
  security_group_ids  = [aws_security_group.db.id]
  publicly_accessible = true
  subnet_group_name   = "main-db-public-subnet-group"
}

module "ecs_auth" {
  source             = "./modules/ecs_service"
  name               = "auth"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  image              = var.auth_image
  cluster_arn        = aws_ecs_cluster.main.arn
  security_group_ids = [aws_security_group.services.id]
  listener_arn       = aws_lb_listener.http.arn
  path_patterns      = [local.service_paths.auth, "${local.service_paths.auth}/*"]
  priority           = 10
  environment = {
    DB_HOST    = module.rds.rds_host
    DB_USER    = var.db_username
    DB_PASSWORD = var.db_password
    DB_PASS     = var.db_password
    DB_PORT    = tostring(var.db_port)
    DB_NAME    = var.db_name
    JWT_SECRET = var.jwt_secret
    JWT_EXPIRY = var.jwt_expiry
  }
}

module "ecs_user" {
  source             = "./modules/ecs_service"
  name               = "user"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  image              = var.user_image
  cluster_arn        = aws_ecs_cluster.main.arn
  security_group_ids = [aws_security_group.services.id]
  listener_arn       = aws_lb_listener.http.arn
  path_patterns      = [local.service_paths.user, "${local.service_paths.user}/*"]
  priority           = 20
  environment = {
    DB_HOST    = module.rds.rds_host
    DB_USER    = var.db_username
    DB_PASSWORD = var.db_password
    DB_PASS     = var.db_password
    DB_PORT    = tostring(var.db_port)
    DB_NAME    = var.db_name
    JWT_SECRET = var.jwt_secret
    JWT_EXPIRY = var.jwt_expiry
  }
}

module "ecs_venda" {
  source             = "./modules/ecs_service"
  name               = "venda"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  image              = var.venda_image
  cluster_arn        = aws_ecs_cluster.main.arn
  security_group_ids = [aws_security_group.services.id]
  listener_arn       = aws_lb_listener.http.arn
  path_patterns      = [local.service_paths.venda, "${local.service_paths.venda}/*"]
  priority           = 30
  environment = {
    DB_HOST    = module.rds.rds_host
    DB_USER    = var.db_username
    DB_PASSWORD = var.db_password
    DB_PASS     = var.db_password
    DB_PORT    = tostring(var.db_port)
    DB_NAME    = var.db_name
    JWT_SECRET = var.jwt_secret
    JWT_EXPIRY = var.jwt_expiry
  }
}
