# aws-infra

Terraform infrastructure for the AWS Chat App. Provisions all AWS resources required to run the application in a production-like environment.

## What's in here

| File / Folder | Purpose |
|---|---|
| `main.tf` | All AWS resources: VPC, subnets, security groups, ECR, ECS cluster + services, ALB, RDS, Lambda, SNS, CloudWatch alarms |
| `variables.tf` | Input variable definitions (`db_password`, `notification_email`, `cpu_high_threshold`, `alert_email`) |
| `lambda/alert.py` | Python 3.9 Lambda handler — receives a keyword-triggered payload from the frontend and publishes an alert to SNS |
| `build_and_push.sh` | Builds both Docker images, pushes them to ECR, and forces ECS to redeploy |

## Infrastructure overview

- **VPC** with public subnets (ALB) and private subnets (ECS tasks + RDS). No NAT Gateway — outbound AWS API calls go through VPC Interface Endpoints.
- **Single ALB** on port 80. Path-based routing: `/chat/*` → backend (port 5000), everything else → frontend (port 3000).
- **ECS Fargate** runs two services (frontend + backend) in private subnets with no public IP.
- **RDS PostgreSQL** in a private DB subnet group, accessible only from the backend security group.
- **Lambda + SNS** — keyword alert path: frontend → Lambda Function URL → SNS → email.
- **CloudWatch alarms** — CPU high (frontend + backend), memory high (frontend + backend), and all tasks stopped → SNS → email.

## How it evolved (lab history)

| Lab | Key change |
|---|---|
| 9 | Initial setup: two ALBs, public subnets, two ECS services |
| 10 | Single ALB with path-based routing, ECS tasks moved to private subnets |
| 11 | Added RDS PostgreSQL for message persistence |
| 12 | Added CloudWatch alarms + SNS email notifications |
| 13 | Added Lambda keyword alert path + VPC endpoints (replaced NAT Gateway) |

For full deployment instructions see the [root README](../README.md).
