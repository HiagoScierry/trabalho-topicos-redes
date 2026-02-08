variable "name" {
  description = "Logical name for the ECS service"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the service runs"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets attached to the ECS service"
  type        = list(string)
}

variable "image" {
  description = "Container image to deploy"
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster ARN where the service is deployed"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups applied to the service ENIs"
  type        = list(string)
}

variable "listener_arn" {
  description = "Application Load Balancer listener ARN"
  type        = string
}

variable "path_patterns" {
  description = "List of path patterns that route traffic to this service"
  type        = list(string)
}

variable "priority" {
  description = "Priority for the listener rule"
  type        = number
}

variable "container_port" {
  description = "Container port exposed by the service"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Path used for target group health checks"
  type        = string
  default     = "/"
}

variable "environment" {
  description = "Environment variables injected into the container"
  type        = map(string)
  default     = {}
}

locals {
  container_environment = merge(
    {
      NODE_ENV = "production"
      PORT     = tostring(var.container_port)
    },
    var.environment
  )
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  container_definitions    = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true
      portMappings = [{
        containerPort = var.container_port
      }]
      environment = [
        for key in sort(keys(local.container_environment)) : {
          name  = key
          value = local.container_environment[key]
        }
      ]
    }
  ])
}

resource "aws_lb_target_group" "main" {
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener_rule" "path_based" {
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }
}

resource "aws_iam_role" "ecs_task_exec" {
  name = "${var.name}-ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "main" {
  name            = "${var.name}-service"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.path_based]
}
