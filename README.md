# Lab 13 - ECS Chat Application with RDS, CloudWatch, and Lambda Alerts

This laboratory deploys a chat application on AWS using Terraform. The stack runs the frontend and backend on ECS Fargate, stores chat data in PostgreSQL on RDS, exposes the app through a single Application Load Balancer, and sends both CloudWatch alarms and keyword-based chat alerts by e-mail.

## Architecture

The application uses the following AWS services:

- VPC with public and private subnets
- Application Load Balancer for public access
- Two ECS Fargate services, one for the frontend and one for the backend
- Amazon ECR repositories for container images
- Amazon RDS PostgreSQL for persistence
- Amazon SNS and CloudWatch alarms for monitoring
- AWS Lambda for keyword-triggered chat notifications

The topology is summarized in the diagram below:

Traffic flow:

- `/` routes to the frontend service
- `/chat` and `/chat/*` route to the backend service
- The backend connects to RDS in private subnets
- ECS tasks use the private subnets and VPC endpoints for outbound access to AWS services
- When a configured keyword is present in a chat message, the frontend sends the full message to the Lambda function URL
- The Lambda function publishes the alert to SNS, and SNS delivers it by e-mail

## Terraform Resources

The infrastructure is defined entirely in Terraform:

- `main.tf` creates the VPC, security groups, RDS database, ECR repositories, ECS cluster, task definitions, services, load balancer, SNS topic, and CloudWatch alarms.
- `variables.tf` defines the input values used by the deployment.
- `lambda/alert.py` contains the Lambda handler that formats the alert and publishes it to SNS.

The key resources are:

- `aws_db_instance.chat_db` for the PostgreSQL database
- `aws_ecs_cluster.chat_cluster` for the ECS cluster
- `aws_ecs_service.backend_svc` and `aws_ecs_service.frontend_svc` for the running application
- `aws_lb.chat_alb` for the public entry point
- `aws_sns_topic.monitoring_alerts` for alarm notifications
- `aws_cloudwatch_metric_alarm.cpu_high` for CPU alarms
- `aws_cloudwatch_metric_alarm.all_tasks_stopped` for the stopped-tasks alarm
- `aws_sns_topic.chat_alerts` for keyword-based chat notifications
- `aws_lambda_function.chat_alert_lambda` for the alert processor
- `aws_lambda_function_url.chat_alert_url` for public invocation from the frontend

## Keyword-Based Chat Alerts

The last lab requirement adds a second notification path to the chat application.

The flow is:

1. The user types a message in the chat frontend.
2. The frontend checks whether the message contains a chosen keyword.
3. If the keyword is present, the frontend sends the complete message payload to the Lambda function URL.
4. Terraform passes the SNS topic ARN to the Lambda function through the `SNS_TOPIC_ARN` environment variable.
5. The Lambda function reads the request body, adds the message timestamp, and publishes the alert to SNS.
6. SNS sends the alert by e-mail to the address configured in `alert_email`.

The keyword can be any word you choose in the frontend logic. The important part is that the entire original message is forwarded, not just the matching word.

### Lambda function

The alert Lambda is implemented in Python 3.9 in `lambda/alert.py` and is packaged by Terraform with `archive_file`.

The handler does the following:

- Reads the request body and parses the JSON payload.
- Extracts `message` from the payload.
- Extracts `timestamp` from the payload, or uses the current time if it is missing.
- Builds a text message that includes both values.
- Publishes the formatted message to the SNS topic identified by `SNS_TOPIC_ARN`.
- Returns a JSON response with the SNS message ID on success.

The Lambda resource is configured with:

- `function_name = "chat_alert_handler"`
- `handler = "alert.lambda_handler"`
- `runtime = "python3.9"`
- `authorization_type = "NONE"` on the function URL so the frontend can invoke it directly

Terraform also attaches CORS settings to the function URL so the browser-based frontend can call it from the chat page.

## Monitoring With CloudWatch

CloudWatch monitoring is configured for the two ECS services in the application.

### CPU alarm

CPU alarms are created for both the backend and the frontend service. The threshold is controlled by the Terraform input variable `cpu_high_threshold`.

When the CPU utilization of either service stays above the threshold, CloudWatch sends an e-mail through the SNS topic.

### Tasks stopped alarm

The `chat-all-tasks-stopped` alarm watches the running task count of both ECS services. If the total number of running tasks drops to zero, CloudWatch sends an e-mail alert.

### E-mail notifications

Notifications are delivered through an SNS topic with an e-mail subscription. The first deployment creates the subscription, but the recipient must confirm it from the e-mail AWS sends.

This monitoring path is separate from the chat keyword alert path:

- CloudWatch alarms use `aws_sns_topic.monitoring_alerts`
- Chat keyword alerts use `aws_sns_topic.chat_alerts`

## Input Variables

The deployment expects these variables:

- `db_username`: PostgreSQL master username
- `db_password`: PostgreSQL master password
- `notification_email`: e-mail address that receives CloudWatch notifications
- `cpu_high_threshold`: CPU percentage used by the CloudWatch alarm
- `alert_email`: e-mail address that receives the Lambda/SNS chat alert notifications

The CPU threshold is validated to stay between 1 and 100.

## Deploying The Stack

1. Initialize Terraform:

```bash
terraform init
```

2. Apply the stack with your values:

```bash
terraform apply \
  -var="db_username=admin" \
  -var="db_password=<secret>" \
  -var="notification_email=<your-email@example.com>" \
  -var="alert_email=<your-alert@example.com>" \
  -var="cpu_high_threshold=75"
```

3. Build and push the container images to ECR:

```bash
bash build_and_push.sh
```

4. Confirm the SNS subscription from the e-mail AWS sends to `notification_email`.

5. Confirm the SNS subscription for `alert_email` as well. The chat alert topic also sends a confirmation message when the subscription is first created.

After the deployment finishes, Terraform prints the application URL and the ECR repository URLs.

## Database Schema

The PostgreSQL database stores chat messages in a single table with these columns:

- `id`
- `username`
- `message`
- `timestamp`

The schema is created by `init.sql` and is used by the backend to persist messages across container restarts. The `timestamp` column is also reused by the Lambda alert payload so the notification e-mail can show when the message was generated.

## Terraform Summary

The Terraform configuration is split into two related parts:

- The core chat stack, which includes VPC, ECS, ALB, ECR, and RDS resources.
- The alerting stack, which includes the SNS topic, Lambda function, Lambda function URL, and e-mail subscription.

The most relevant environment variables are:

- `PUBLIC_API_BASE_URL`, which points the frontend to the ALB-backed API
- `PUBLIC_LAMBDA_URL`, which points the frontend to the Lambda function URL
- `SNS_TOPIC_ARN`, which tells the Lambda function where to publish alerts

## Result

After deployment, the application is reachable through the ALB, chat data persists in RDS, CloudWatch sends e-mail alerts when:

- the CPU load of either ECS service exceeds the configured threshold
- all application tasks stop running

and the chat alert path sends a separate e-mail whenever the frontend detects the selected keyword in a chat message.
