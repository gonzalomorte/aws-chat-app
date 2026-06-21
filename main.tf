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
data "aws_region" "current" {}

# ====================
# VPC — public subnets (ALB) + private subnets (ECS tasks + RDS)
# Private access is provided through VPC endpoints instead of NAT.
# ====================
module "my_vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = "chat-ecs"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway     = false
  single_nat_gateway     = false
  one_nat_gateway_per_az = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# ====================
# VPC Endpoints — private access to AWS services used by ECS tasks
# ====================
resource "aws_security_group" "vpce_sg" {
  name        = "vpce_sg"
  description = "Allow ECS tasks to reach interface VPC endpoints over TLS"
  vpc_id      = module.my_vpc.vpc_id

  tags = {
    Name = "vpce-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_allow_https_from_chat" {
  security_group_id            = aws_security_group.vpce_sg.id
  referenced_security_group_id = aws_security_group.chat_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "vpce_allow_all" {
  security_group_id = aws_security_group.vpce_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.my_vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.my_vpc.private_route_table_ids
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.my_vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.my_vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.my_vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.my_vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.my_vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.my_vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.my_vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.my_vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = module.my_vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.my_vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.my_vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.my_vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

# ====================
# Security Group — ALB, frontend, backend
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
# Security Group — RDS (only backend ECS tasks via chat_sg can reach port 5432)
# ====================
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow PostgreSQL access only from backend ECS tasks"
  vpc_id      = module.my_vpc.vpc_id
  tags = {
    Name = "rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_postgres" {
  security_group_id            = aws_security_group.rds_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.chat_sg.id
}

resource "aws_vpc_security_group_egress_rule" "rds_allow_all" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ====================
# RDS — PostgreSQL in private subnets
# ====================
resource "aws_db_subnet_group" "chat_db" {
  name       = "chat-db-subnet-group"
  subnet_ids = module.my_vpc.private_subnets
}

resource "aws_db_instance" "chat_db" {
  identifier             = "chat-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "chatdb"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.chat_db.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = { Name = "chat-db" }
}

# ====================
# ECR Repositories
# ====================
resource "aws_ecr_repository" "chat_backend" {
  name         = "chat-backend"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "chat-backend" }
}

resource "aws_ecr_repository" "chat_frontend" {
  name         = "chat-frontend"
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

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ====================
# CloudWatch Monitoring
# ====================
resource "aws_sns_topic" "monitoring_alerts" {
  name = "chat-monitoring-alerts"
}

resource "aws_sns_topic_subscription" "monitoring_email" {
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

locals {
  ecs_services = {
    backend  = aws_ecs_service.backend_svc.name
    frontend = aws_ecs_service.frontend_svc.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each = local.ecs_services

  alarm_name          = "${each.key}-cpu-high"
  alarm_description   = "Triggers when the ${each.key} ECS service CPU utilization is above ${var.cpu_high_threshold}%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.chat_cluster.name
    ServiceName = each.value
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  for_each = local.ecs_services

  alarm_name          = "${each.key}-memory-high"
  alarm_description   = "Triggers when the ${each.key} ECS service memory utilization is above 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.chat_cluster.name
    ServiceName = each.value
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "all_tasks_stopped" {
  alarm_name          = "chat-all-tasks-stopped"
  alarm_description   = "Triggers when the total number of running ECS tasks in this application drops to zero"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "breaching"

  metric_query {
    id          = "backend_running_tasks"
    return_data = false

    metric {
      metric_name = "RunningTaskCount"
      namespace   = "AWS/ECS"
      period      = 60
      stat        = "Average"

      dimensions = {
        ClusterName = aws_ecs_cluster.chat_cluster.name
        ServiceName = aws_ecs_service.backend_svc.name
      }
    }
  }

  metric_query {
    id          = "frontend_running_tasks"
    return_data = false

    metric {
      metric_name = "RunningTaskCount"
      namespace   = "AWS/ECS"
      period      = 60
      stat        = "Average"

      dimensions = {
        ClusterName = aws_ecs_cluster.chat_cluster.name
        ServiceName = aws_ecs_service.frontend_svc.name
      }
    }
  }

  metric_query {
    id          = "total_running_tasks"
    expression  = "backend_running_tasks + frontend_running_tasks"
    label       = "TotalRunningTasks"
    return_data = true
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
}

# ====================
# ALB — / -> frontend | /chat/* -> backend
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

resource "aws_lb_listener" "chat_listener" {
  load_balancer_arn = aws_lb.chat_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

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
# BACKEND — Task Definition & Service (private subnet)
# DB connection injected as environment variables from RDS outputs
# ====================
resource "aws_ecs_task_definition" "backend_task" {
  family                   = "chat-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "512"
  cpu                      = "256"
  task_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  container_definitions = jsonencode([
    {
      name      = "chat-backend"
      image     = "${aws_ecr_repository.chat_backend.repository_url}:latest"
      memory    = 512
      cpu       = 256
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
      environment = [
        { name = "DB_HOST", value = aws_db_instance.chat_db.address },
        { name = "DB_NAME", value = "chatdb" },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PASSWORD", value = var.db_password }
      ]
    }
  ])

  depends_on = [aws_db_instance.chat_db]
}

resource "aws_ecs_service" "backend_svc" {
  name                   = "chat-backend-svc"
  cluster                = aws_ecs_cluster.chat_cluster.id
  task_definition        = aws_ecs_task_definition.backend_task.arn
  launch_type            = "FARGATE"
  desired_count          = 1
  enable_execute_command = true

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

  depends_on = [aws_lb_listener_rule.chat_rule]
}

# ====================
# FRONTEND — Task Definition & Service (private subnet)
# PUBLIC_API_BASE_URL points to ALB — frontend appends /chat/...
# ====================
resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "chat-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "512"
  cpu                      = "256"
  task_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  container_definitions = jsonencode([
    {
      name      = "chat-frontend"
      image     = "${aws_ecr_repository.chat_frontend.repository_url}:latest"
      memory    = 512
      cpu       = 256
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      environment = [
        { name = "PUBLIC_API_BASE_URL", value = "http://${aws_lb.chat_alb.dns_name}" },
        { name = "PUBLIC_LAMBDA_URL", value = aws_lambda_function_url.chat_alert_url.function_url }
      ]
    }
  ])
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
  description = "Single entry point: / -> frontend, /chat/* -> backend"
  value       = "http://${aws_lb.chat_alb.dns_name}"
}

output "ecr_backend_url" {
  value = aws_ecr_repository.chat_backend.repository_url
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.chat_frontend.repository_url
}

output "rds_host" {
  description = "RDS endpoint — use to run init.sql from inside the VPC"
  value       = aws_db_instance.chat_db.address
}

# ====================
# Chat Alert SNS & Lambda
# ====================
resource "aws_sns_topic" "chat_alerts" {
  name = "chat-keyword-alerts"
}

resource "aws_sns_topic_subscription" "chat_alerts_email" {
  topic_arn = aws_sns_topic.chat_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "archive_file" "lambda_alert_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/alert.py"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_lambda_function" "chat_alert_lambda" {
  filename         = data.archive_file.lambda_alert_zip.output_path
  function_name    = "chat_alert_handler"
  role             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler          = "alert.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_alert_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.chat_alerts.arn
    }
  }
}

resource "aws_lambda_function_url" "chat_alert_url" {
  function_name      = aws_lambda_function.chat_alert_lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive", "content-type", "x-amz-date", "authorization"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

output "lambda_alert_url" {
  value = aws_lambda_function_url.chat_alert_url.function_url
}

