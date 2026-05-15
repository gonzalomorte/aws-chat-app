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

# ====================
# VPC
# ====================
module "my_vpc" {
  source         = "terraform-aws-modules/vpc/aws"
  name           = "chat-ecs"
  cidr           = "10.0.0.0/16"
  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# ====================
# Security Group
# Opens port 3000 (frontend) and 5000 (backend)
# ====================
resource "aws_security_group" "chat_sg" {
  name        = "chat_sg"
  description = "Allow frontend (3000) and backend (5000) inbound, all outbound"
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
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "chat-backend" }
}

resource "aws_ecr_repository" "chat_frontend" {
  name = "chat-frontend"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "chat-frontend" }
}

# ====================
# ECS Cluster (shared by both services)
# ====================
resource "aws_ecs_cluster" "chat_cluster" {
  name = "chat-cluster"
}

# ====================
# BACKEND — Load Balancer, Target Group, Listener
# ====================
resource "aws_lb" "backend_lb" {
  name                       = "chat-backend-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.chat_sg.id]
  subnets                    = module.my_vpc.public_subnets
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "backend_tg" {
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = module.my_vpc.vpc_id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-404" # adjust if your backend has no root route
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.backend_lb.arn
  port              = 5000
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# ====================
# BACKEND — ECS Task Definition & Service
# ====================
resource "aws_ecs_task_definition" "backend_task" {
  family                   = "chat-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "512"
  cpu                      = "256"
  task_role_arn            = "arn:aws:iam::048630774961:role/LabRole"
  execution_role_arn       = "arn:aws:iam::048630774961:role/LabRole"

  container_definitions = <<-EOF
[
  {
    "name": "chat-backend",
    "image": "048630774961.dkr.ecr.us-east-1.amazonaws.com/chat-backend:latest",
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
    subnets          = module.my_vpc.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.chat_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "chat-backend"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.backend_listener]
}

