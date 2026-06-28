#!/bin/bash
set -e

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
REPO_DIR="app"

echo "==> Account: ${ACCOUNT_ID}"
echo "==> ECR base: ${ECR_BASE}"

# ==================
# 1. Use local app directory
# ==================
echo "==> Using local app directory..."
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
# 7. Force ECS to redeploy with the new images
# ─────────────────────────────────────────────
echo "==> Forcing ECS redeployment..."
aws ecs update-service --cluster chat-cluster --service chat-backend-svc  --force-new-deployment --region "$REGION" > /dev/null
aws ecs update-service --cluster chat-cluster --service chat-frontend-svc --force-new-deployment --region "$REGION" > /dev/null

# ─────────────────────────────────────────────
# 8. Print URLs
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