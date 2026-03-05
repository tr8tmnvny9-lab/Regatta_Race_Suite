#!/bin/bash
set -e

# ==========================================
# Regatta Suite - AWS Fargate Deployment Script
# ==========================================
# This script builds the backend-rust image, pushes it to AWS ECR,
# and forces a rolling update on the ECS Fargate cluster.
#
# Prerequisite: aws-cli configured with active credentials.

AWS_REGION="eu-north-1" # Stockholm (Closest to Nordic Sailing)
AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
ECR_REPO_NAME="regatta-backend"
CLUSTER_NAME="RegattaCloudCluster"
SERVICE_NAME="RegattaBackendService"
IMAGE_TAG="latest"

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}"

echo "🚀 Starting Deployment for Regatta Backend to AWS Fargate..."

# 1. Authenticate Docker to Amazon ECR
echo "🔐 Authenticating with ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 2. Build the Docker Image
echo "🐳 Building Docker image..."
# Move one level up to include workspace members (packages/uwb-types)
cd ..
docker build -t ${ECR_REPO_NAME} -f backend-rust/Dockerfile .

# 3. Tag and Push
echo "🏷️ Tagging and pushing image to ECR: ${ECR_URI}"
docker tag ${ECR_REPO_NAME}:latest ${ECR_URI}
docker push ${ECR_URI}

# 4. Force ECS Fargate Deployment
echo "☁️ Forcing new deployment on ECS Cluster: ${CLUSTER_NAME}"
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment \
    --region $AWS_REGION

echo "✅ Deployment initiated! Check AWS ECS Console for rollout status."
