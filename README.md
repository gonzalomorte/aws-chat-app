# AWS Chat App

A full-stack real-time chat application deployed on AWS using ECS Fargate, RDS PostgreSQL, an Application Load Balancer, and a Lambda-powered keyword alert system. Infrastructure is fully managed with Terraform.

## Architecture Overview

```
Internet
   │
   ▼
[ALB :80]
   ├── /           → ECS Fargate — Frontend (SvelteKit :3000)   ┐
   └── /chat/*     → ECS Fargate — Backend  (Spring Boot :5000)  ├── Private subnets
                              │                                   │
                         [RDS PostgreSQL]  ──────────────────────┘
                              │
                         [Lambda]  →  [SNS]  →  Email alerts
```

**Key design decisions:**
- No NAT Gateway — private ECS tasks reach ECR/CloudWatch/SSM through **VPC Interface Endpoints**, keeping costs low.
- Single ALB entry point: path-based routing forwards `/chat/*` to the backend and everything else to the frontend.
- CloudWatch alarms notify via SNS on high CPU, high memory, or zero running tasks.
- A Lambda Function URL (no auth) accepts keyword-trigger requests from the frontend and publishes to a dedicated SNS topic.

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | SvelteKit + TypeScript |
| Backend | Spring Boot (Java / Gradle) |
| Database | PostgreSQL 15 on RDS (private subnet) |
| Container registry | Amazon ECR |
| Orchestration | Amazon ECS Fargate |
| Load balancer | Application Load Balancer |
| Serverless | AWS Lambda (Python 3.9) |
| Messaging | Amazon SNS |
| Monitoring | CloudWatch Alarms + SNS |
| IaC | Terraform ≥ 1.2.0 |

## Repository Structure

```
aws-chat-app/
├── chat-app/
│   ├── backend/          # Spring Boot REST API (port 5000)
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── build.gradle
│   ├── frontend/         # SvelteKit app (port 3000)
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── package.json
│   └── docker-compose.yml
└── aws-infra/
    ├── main.tf           # All AWS resources
    ├── variables.tf      # Input variables
    ├── init.sql          # DB schema initialisation
    ├── lambda/
    │   └── alert.py      # Keyword alert Lambda
    └── build_and_push.sh # Build images & push to ECR
```

## Prerequisites

Before starting, make sure you have the following available in your AWS Cloud9 environment:

- An AWS Academy / IAM account with a **`LabRole`** IAM role already created (the Terraform config references it by name)
- AWS CLI configured — Cloud9 instances have credentials pre-injected via instance profile, no manual setup needed
- Terraform ≥ 1.2.0
- Docker
- Java 17+ (for building the Spring Boot backend locally if needed)
- Node.js 18+ (for building the frontend locally if needed)

## Step-by-step Deployment on AWS Cloud9

### 1. Open or create a Cloud9 environment

1. Go to the [AWS Console](https://console.aws.amazon.com) → **Cloud9** → **Create environment**.
2. Choose **t3.small** or larger (Docker builds are memory-intensive).
3. Select **Amazon Linux 2023** as the platform.
4. Once the environment is ready, open the terminal at the bottom.

### 2. Install Terraform

```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform
terraform -version   # should print >= 1.2.0
```

### 3. Clone this repository

```bash
git clone https://github.com/gonzalomorte/aws-chat-app.git
cd aws-chat-app
```

### 4. Provision the infrastructure with Terraform

Terraform will create the VPC, subnets, VPC endpoints, security groups, RDS instance, ECR repositories, ECS cluster, ALB, Lambda, and all CloudWatch alarms.

```bash
cd aws-infra
terraform init
terraform apply
```

Terraform will prompt you for the following variables:

| Variable | Description | Example |
|---|---|---|
| `db_password` | RDS master password (min 8 chars) | `MyP@ssw0rd` |
| `notification_email` | Email for CloudWatch alarm notifications | `you@example.com` |
| `cpu_high_threshold` | CPU % that triggers the high-CPU alarm | `80` |
| `alert_email` | Email for chat keyword alerts via Lambda/SNS | `you@example.com` |

> **Check your inbox** — AWS SNS will send a confirmation email to both addresses. You must click **Confirm subscription** before alerts can be delivered.

After `terraform apply` completes, note the outputs:

```
app_url             = "http://<alb-dns-name>"
ecr_backend_url     = "<account>.dkr.ecr.us-east-1.amazonaws.com/chat-backend"
ecr_frontend_url    = "<account>.dkr.ecr.us-east-1.amazonaws.com/chat-frontend"
rds_host            = "chat-db.<xyz>.us-east-1.rds.amazonaws.com"
lambda_alert_url    = "https://<id>.lambda-url.us-east-1.on.aws/"
```

### 5. Initialise the database schema

The `init.sql` file creates the required tables. Run it from inside the VPC using the AWS CLI SSM Session Manager or from any ECS task that has access to the RDS instance.

The easiest approach on Cloud9 is to temporarily install the PostgreSQL client and connect via a bastion — or use the ECS Exec feature once a task is running:

```bash
# Install psql client on Cloud9 (Amazon Linux 2023)
sudo dnf install -y postgresql15

# Connect using the RDS host from Terraform output
psql -h <rds_host> -U chatuser -d chatdb -f aws-infra/init.sql
# Enter the db_password you set during terraform apply when prompted
```

### 6. Build the Docker images and push them to ECR

The `build_and_push.sh` script automates this entirely. It:
1. Authenticates Docker with ECR using your current AWS credentials.
2. Builds the backend image from `chat-app/backend/Dockerfile`.
3. Builds the frontend image from `chat-app/frontend/Dockerfile`.
4. Tags both images as `latest` and `v1`.
5. Pushes all tags to ECR.
6. Forces ECS to redeploy both services with the new images.

```bash
cd aws-infra
chmod +x build_and_push.sh
./build_and_push.sh
```

The script will print the ECR image URLs and the ALB URL at the end.

> **Note:** Cloud9 instances automatically inherit the IAM role of the environment. No AWS credentials need to be hardcoded or exported.

### 7. Access the application

Once ECS finishes deploying (usually 1–2 minutes after the push), open your browser:

```
Frontend → http://<app_url>/
Backend  → http://<app_url>/chat/all?username=test
```

Use the `app_url` printed by `terraform apply` or run:

```bash
cd aws-infra
terraform output app_url
```

## Terraform Variables Reference

All variables are defined in `aws-infra/variables.tf`. You can also provide them via a `terraform.tfvars` file to avoid being prompted each time:

```hcl
# aws-infra/terraform.tfvars  — DO NOT commit this file
db_username           = "chatuser"
db_password           = "YourSecurePassword"
notification_email    = "you@example.com"
alert_email           = "you@example.com"
cpu_high_threshold    = 80
```

Add `terraform.tfvars` to `.gitignore` to avoid accidentally committing credentials.

## Tearing Down

To destroy all AWS resources and avoid ongoing charges:

```bash
cd aws-infra
terraform destroy
```

> **Warning:** This will delete the RDS instance, all ECS services, the ALB, ECR repositories (including all pushed images), and all VPC resources. The operation is irreversible.

## Local Development (without AWS)

You can run the full stack locally using Docker Compose:

```bash
cd chat-app
docker compose up --build
```

This starts the backend on port `5000` and the frontend on port `3000`. The frontend proxies API calls to the backend automatically. No AWS credentials are needed for local development.

## Monitoring

The following CloudWatch alarms are created automatically by Terraform:

| Alarm | Condition | Action |
|---|---|---|
| `backend-cpu-high` | Backend CPU ≥ threshold | SNS → email |
| `frontend-cpu-high` | Frontend CPU ≥ threshold | SNS → email |
| `backend-memory-high` | Backend memory ≥ 80% | SNS → email |
| `frontend-memory-high` | Frontend memory ≥ 80% | SNS → email |
| `chat-all-tasks-stopped` | Total running tasks = 0 | SNS → email |

The keyword alert Lambda (`aws-infra/lambda/alert.py`) is triggered directly by the frontend via its Function URL and publishes a message to the `chat-keyword-alerts` SNS topic, which delivers it to the `alert_email` address.
