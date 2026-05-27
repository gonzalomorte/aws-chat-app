#!/bin/bash
set -e

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
REPO_URL="https://gonzalomorte:TOKEN_REMOVED@github.com/pwr-cloudprogramming/clprog2026-a04-mon1506.git"
REPO_DIR="clprog2026-a04-mon1506"
TAG="lab11_db" # Target for lab 11

echo "==> Account: ${ACCOUNT_ID}"
echo "==> ECR base: ${ECR_BASE}"

# ==================
# 1. Clone the private repository
# ==================
if [ -d "$REPO_DIR" ]; then
  echo "==> Directory ${REPO_DIR} already exists, fetching latest tags..."
  cd "$REPO_DIR"
  git fetch origin --tags
  git checkout "$TAG"
  cd ..
else
  echo "==> Cloning specific tag from repository..."
  git clone --branch "$TAG" --depth 1 "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# ─────────────────────────────────────────────
# 2. Log in to ECR
# ─────────────────────────────────────────────
echo "==> Logging in to ECR..."
aws ecr get-login-password --region "$REGION"   | docker login --username AWS --password-stdin "$ECR_BASE"

# ─────────────────────────────────────────────
# 3. Build backend image
# ─────────────────────────────────────────────
echo "==> Building backend image..."
docker build -t chat-backend:latest -t chat-backend:v1 ./backend

# ─────────────────────────────────────────────
# 4. Build frontend image
# ─────────────────────────────────────────────
echo "==> Building frontend image..."
docker build -t chat-frontend:latest -t chat-frontend:v1 ./frontend

# ─────────────────────────────────────────────
# 5. Tag images for ECR
# ─────────────────────────────────────────────
echo "==> Tagging images for ECR..."
docker tag chat-backend:latest  "${ECR_BASE}/chat-backend:latest"
docker tag chat-backend:v1      "${ECR_BASE}/chat-backend:v1"
docker tag chat-frontend:latest "${ECR_BASE}/chat-frontend:latest"
docker tag chat-frontend:v1     "${ECR_BASE}/chat-frontend:v1"

# ─────────────────────────────────────────────
# 6. Push images to ECR
# ─────────────────────────────────────────────
echo "==> Pushing backend to ECR..."
docker push "${ECR_BASE}/chat-backend:latest"
docker push "${ECR_BASE}/chat-backend:v1"

echo "==> Pushing frontend to ECR..."
docker push "${ECR_BASE}/chat-frontend:latest"
docker push "${ECR_BASE}/chat-frontend:v1"

# ─────────────────────────────────────────────
# 7. Create database table directly on RDS (BEFORE starting services)
# ─────────────────────────────────────────────
echo "==> Creating database table on RDS..."
RDS_HOST=$(cd "$SCRIPT_DIR" && terraform output -raw rds_host 2>/dev/null || echo "")

if [ -z "$RDS_HOST" ]; then
  echo "WARNING: Could not read rds_host from terraform output"
else
  # Use docker to create table (no SessionManagerPlugin needed)
  docker run --rm postgres:15 \
    psql "postgresql://${DB_USERNAME}:${DB_PASSWORD}@${RDS_HOST}:5432/chatdb" \
    -c "CREATE TABLE IF NOT EXISTS chat_message (id BIGSERIAL PRIMARY KEY, username VARCHAR(100) NOT NULL, message TEXT NOT NULL, timestamp TIMESTAMP NOT NULL);" \
    && echo "==> Database table created" || echo "WARNING: Could not create table"
fi

# ─────────────────────────────────────────────
# 8. Force ECS to redeploy with the new images
# ─────────────────────────────────────────────
echo "==> Forcing ECS redeployment..."
aws ecs update-service --cluster chat-cluster --service chat-backend-svc  --force-new-deployment --region "$REGION" > /dev/null
aws ecs update-service --cluster chat-cluster --service chat-frontend-svc --force-new-deployment --region "$REGION" > /dev/null

echo "==> Waiting for backend service to stabilise (this takes ~2 min)..."
aws ecs wait services-stable --cluster chat-cluster --services chat-backend-svc --region "$REGION"

# ─────────────────────────────────────────────
# 9. Print URLs
# ─────────────────────────────────────────────
echo ""
ALB_DNS=$(aws elbv2 describe-load-balancers   --names "chat-alb"   --query "LoadBalancers[0].DNSName"   --output text 2>/dev/null || echo "ALB not found — run terraform apply first")

echo "  Done! Images pushed:"
echo "  ${ECR_BASE}/chat-backend:latest"
echo "  ${ECR_BASE}/chat-backend:v1"
echo "  ${ECR_BASE}/chat-frontend:latest"
echo "  ${ECR_BASE}/chat-frontend:v1"
echo ""
echo "  App URL:"
echo "  Frontend → http://${ALB_DNS}/"
echo "  Backend  → http://${ALB_DNS}/chat/all?username=test"