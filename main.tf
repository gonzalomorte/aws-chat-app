terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.1"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

# Get the current AWS account ID dynamically
data "aws_caller_identity" "current" {}

# ====================
# VPC — subnets públicas (ALB) + privadas (ECS tasks)
# ====================
module "my_vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = "chat-ecs"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# ====================
# Security Group
# ====================
resource "aws_security_group" "chat_sg" {
  name        = "chat_sg"
  description = "Allow ALB (80), frontend (3000) and backend (5000) inbound, all outbound"
  vpc_id      = module.my_vpc.vpc_id
  tags = {
    Name = "chat-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.chat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.chat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_frontend" {
  security_group_id = aws_security_group.chat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
}

resource "aws_vpc_security_group_ingress_rule" "allow_backend" {
  security_group_id = aws_security_group.chat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 5000
  to_port           = 5000
}

# ====================
# ECR Repositories
# ====================
resource "aws_ecr_repository" "chat_backend" {
  name = "chat-backend"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "chat-backend" }
}

resource "aws_ecr_repository" "chat_frontend" {
  name = "chat-frontend"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "chat-frontend" }
}

# ====================
# ECS Cluster
# ====================
resource "aws_ecs_cluster" "chat_cluster" {
  name = "chat-cluster"
}

# ====================
# ÚNICO ALB público — subredes públicas
# / → frontend | /chat/* → backend
# ====================
resource "aws_lb" "chat_alb" {
  name                       = "chat-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.chat_sg.id]
  subnets                    = module.my_vpc.public_subnets
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "frontend_tg" {
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.my_vpc.vpc_id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "backend_tg" {
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = module.my_vpc.vpc_id
  target_type = "ip"
  health_check {
    path                = "/chat/all?username=test"
    protocol            = "HTTP"
    matcher             = "200-404"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener :80 — default → frontend
resource "aws_lb_listener" "chat_listener" {
  load_balancer_arn = aws_lb.chat_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# Regla: /chat/* y /api/* → backend
resource "aws_lb_listener_rule" "chat_rule" {
  listener_arn = aws_lb_listener.chat_listener.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/chat", "/chat/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# ====================
# BACKEND — Task Definition & Service en subred PRIVADA
# ====================
resource "aws_ecs_task_definition" "backend_task" {
  family                   = "chat-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "512"
  cpu                      = "256"
  task_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  container_definitions = <<-EOF
[
  {
    "name": "chat-backend",
    "image": "${aws_ecr_repository.chat_backend.repository_url}:latest",
    "memory": 512,
    "cpu": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 5000,
        "hostPort": 5000
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "backend_svc" {
  name            = "chat-backend-svc"
  cluster         = aws_ecs_cluster.chat_cluster.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = module.my_vpc.private_subnets
    assign_public_ip = false
    security_groups  = [aws_security_group.chat_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "chat-backend"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener_rule.chat_rule] # fix: era api_rule
}

# ====================
# FRONTEND — Task Definition & Service en subred PRIVADA
# PUBLIC_API_BASE_URL apunta al ALB — el frontend concatena /chat/...
# ====================
resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "chat-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "512"
  cpu                      = "256"
  task_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  container_definitions = <<-EOF
[
  {
    "name": "chat-frontend",
    "image": "${aws_ecr_repository.chat_frontend.repository_url}:latest",
    "memory": 512,
    "cpu": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000
      }
    ],
    "environment": [
      {
        "name": "PUBLIC_API_BASE_URL",
        "value": "http://${aws_lb.chat_alb.dns_name}"
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "frontend_svc" {
  name            = "chat-frontend-svc"
  cluster         = aws_ecs_cluster.chat_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = module.my_vpc.private_subnets
    assign_public_ip = false
    security_groups  = [aws_security_group.chat_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "chat-frontend"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.chat_listener,
    aws_ecs_service.backend_svc
  ]
}

# ====================
# Outputs
# ====================
output "app_url" {
  description = "Punto de entrada unico: / -> frontend, /chat/* -> backend"
  value       = "http://${aws_lb.chat_alb.dns_name}"
}

output "ecr_backend_url" {
  value = aws_ecr_repository.chat_backend.repository_url
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.chat_frontend.repository_url
}
