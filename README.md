## Lab 11 - Persistent Chat with RDS PostgreSQL

This section documents the infrastructure and code changes introduced in Lab 11: adding a managed PostgreSQL database (Amazon RDS) to persist chat messages across container restarts.

***

### Architecture Overview

The diagram below shows the full AWS topology. The key addition compared to Lab 4 is the RDS instance placed in a **private subnet**, reachable only from the backend ECS tasks.

![image-20260527205354607](img/2026-05-27_20-54.png)

***

### Terraform

**Private subnet for RDS**

RDS is placed in a dedicated DB subnet group spanning two private subnets. The critical part is that these subnets have **no route to an internet gateway**, making the database unreachable from outside the VPC:

```hcl
resource "aws_db_subnet_group" "chat_db" {
  subnet_ids = module.my_vpc.private_subnets
}

resource "aws_db_instance" "chat_db" {
  publicly_accessible  = false   # no public endpoint
  db_subnet_group_name = aws_db_subnet_group.chat_db.name
  ...
}
```

**Security Group - backend-only access**

Instead of allowing a CIDR range, the RDS security group references the backend's security group directly. This means only ECS tasks belonging to `aws_security_group.chat_sg` can connect on port 5432 — regardless of their IP address:

```hcl
resource "aws_security_group" "rds_sg" {
  ingress {
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.chat_sg.id
  }
}
```

Using `source_security_group_id` instead of `cidr_blocks` is more secure: access follows the identity of the resource, not its IP. This also works correctly with auto-scaling and task replacements.

**RDS credentials via environment variables**

The DB password is never hardcoded. It is passed as a Terraform variable and injected into the ECS task definition as an environment variable, which Spring Boot reads at startup:

```hcl
environment = [
  { name = "DB_HOST",     value = aws_db_instance.chat_db.address },
  { name = "DB_PASSWORD", value = var.db_password }
]
```

***

### Database Schema

The database contains one table that stores all chat messages:

```
┌─────────────────────────────────────────────────────┐
│                   chat_message                      │
├──────────────┬──────────────┬────────────────────── │
│ Column       │ Type         │ Constraints           │
├──────────────┼──────────────┼───────────────────────│
│ id           │ BIGSERIAL    │ PRIMARY KEY           │
│ username     │ VARCHAR(100) │ NOT NULL              │
│ message      │ TEXT         │ NOT NULL              │
│ timestamp    │ TIMESTAMP    │ NOT NULL              │
└──────────────┴──────────────┴───────────────────────┘
```

`BIGSERIAL` provides auto-incrementing IDs. The `timestamp` column allows messages to be loaded in chronological order. The table is created by `db/init.sql` and validated on startup via `spring.jpa.hibernate.ddl-auto=validate`.

***

### How Database Content Changes

| Operation         | HTTP Endpoint              | When triggered                  | SQL effect                                                   |
| ----------------- | -------------------------- | ------------------------------- | ------------------------------------------------------------ |
| **Store message** | `POST /chat`               | User sends a chat message       | `INSERT INTO chat_message (username, message, timestamp) VALUES (...)` |
| **Load messages** | `GET /chat/all?username=X` | Page load or reconnect          | `SELECT * FROM chat_message ORDER BY timestamp ASC`          |
| **Clear chat**    | `DELETE /chat`             | User clicks "Clear Chat" button | `DELETE FROM chat_message`                                   |

**Store** - every new message sent by any user is immediately persisted via `chatMessageRepository.save(entity)`. Spring Data JPA maps the Kotlin entity to a row in `chat_message`.

**Retrieve** - on page load the frontend calls `GET /chat/all`, which calls `chatMessageRepository.findAll(Sort.by("timestamp"))`. This returns all stored messages in chronological order so the chat history is restored after restarts or new user connections.

**Delete** - the new `DELETE /chat` endpoint calls `chatMessageRepository.deleteAll()`, which issues a `DELETE FROM chat_message` truncating the entire table. The frontend "Clear Chat" button triggers this endpoint and also clears the local UI state.

***

### Frontend - Clear Chat Button

A single button was added to the chat UI. On click it calls the backend `DELETE /chat` endpoint and clears the rendered message list:

```javascript
async function clearChat() {
  await fetch(`${API_BASE}/chat`, { method: 'DELETE' });
  messages = [];
}
```

The button is only visible to connected users and gives immediate feedback by emptying the UI before the next poll cycle.

***

## Architecture Overview

The chat application runs two ECS Fargate services: a **SvelteKit frontend** (port 3000) and a **Spring Boot backend** (port 5000)  in **private subnets**, behind a **single Application Load Balancer** that routes traffic by URL path:

| Path pattern       | Routed to                                  |
| ------------------ | ------------------------------------------ |
| `/` (default)      | Frontend target group → ECS task port 3000 |
| `/chat`, `/chat/*` | Backend target group → ECS task port 5000  |

Users only ever see one public endpoint: `http://<chat-alb-dns>`. The backend is never directly exposed. A **NAT Gateway** (in the public subnet) provides outbound-only Internet access from  private subnets, which ECS tasks need to pull images from ECR.

***

## Configuration Steps

## 1. Prerequisites

- AWS CLI configured with a profile that has sufficient IAM permissions
- Terraform ≥ 1.2.0
- Docker installed (Cloud9 IDE recommended)

## 2. Deploy Infrastructure

```
bashterraform init
terraform apply -var="db_username=admin" -var="db_password=<secret>"
```

Take note of the outputs:

```
textapp_url          = "http://<chat-alb-dns>"     # single public entry point
ecr_backend_url  = "<account>.dkr.ecr.us-east-1.amazonaws.com/chat-backend"
ecr_frontend_url = "<account>.dkr.ecr.us-east-1.amazonaws.com/chat-frontend"
rds_host         = "<rds-endpoint>.rds.amazonaws.com"
```

## 3. Build & Push Images

Run the shell script to clone, build, and push both images to ECR:

```bash
bash build_and_push.sh
```

The script handles three steps:

**ECR authentication** (token valid for 12 hours):

```bash
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ECR_BASE"
```

**Build both images**:

```bash
docker build -t chat-backend:latest -t chat-backend:v1 ./backend
docker build -t chat-frontend:latest -t chat-frontend:v1 ./frontend
```

**Tag and push** (the `:v1` push is fast — layers are already cached from `:latest`):

```bash
docker tag chat-backend:latest "${ECR_BASE}/chat-backend:latest"
docker push "${ECR_BASE}/chat-backend:latest"
docker push "${ECR_BASE}/chat-backend:v1"
# same for frontend
```

***

## Chat App, Backend & Database Verified

![image-20260527214139232](img/image-20260527214139232.png)

***

## Author Contributions

| Task                                             | Gonzalo Morte Gómez | Jose Daniel Moya Moreno |
| ------------------------------------------------ | ------------------- | ----------------------- |
| Terraform setup (VPC, subnets, NAT Gateway)      |                     | X                       |
| Security Groups (chat_sg, rds_sg)                |                     | X                       |
| ECR repository creation (frontend, backend)      |                     | X                       |
| Docker build & push to ECR (shell script)        | X                   |                         |
| ECS Cluster, Task Definitions & Services         | X                   |                         |
| ALB, Listener, Routing Rules & Target Groups     |                     | X                       |
| RDS PostgreSQL (private subnet, DB subnet group) | X                   |                         |
| README                                           | X                   | X                       |

