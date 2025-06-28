#!/bin/bash

# Deploy Drupal Docker Image to ECS
# This script builds the Docker image and deploys it to ECS using CodeBuild and CodeDeploy

set -e

# Configuration
ENVIRONMENT=${1:-"production"}
REGION=${2:-"us-east-1"}
GITHUB_BRANCH=${3:-"main"}

echo "Starting Drupal Docker deployment..."
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Branch: $GITHUB_BRANCH"

# Get CodeBuild project names from Terraform output
DOCKER_BUILD_PROJECT=$(terraform -chdir=terraform output -raw codebuild_docker_project)
CONTENT_DEPLOY_PROJECT=$(terraform -chdir=terraform output -raw codebuild_content_project)
CODEDEPLOY_APP=$(terraform -chdir=terraform output -raw codedeploy_application)
ECR_REPO_URL=$(terraform -chdir=terraform output -raw ecr_repository_url)

echo "CodeBuild Docker Project: $DOCKER_BUILD_PROJECT"
echo "CodeBuild Content Project: $CONTENT_DEPLOY_PROJECT"
echo "CodeDeploy Application: $CODEDEPLOY_APP"
echo "ECR Repository: $ECR_REPO_URL"

# Start Docker build
echo "Starting Docker image build..."
BUILD_ID=$(aws codebuild start-build \
  --project-name "$DOCKER_BUILD_PROJECT" \
  --source-version "refs/heads/$GITHUB_BRANCH" \
  --region "$REGION" \
  --query 'build.id' \
  --output text)

echo "Docker build started with ID: $BUILD_ID"

# Wait for Docker build to complete
echo "Waiting for Docker build to complete..."
aws codebuild wait build-completed --id "$BUILD_ID" --region "$REGION"

BUILD_STATUS=$(aws codebuild batch-get-builds \
  --ids "$BUILD_ID" \
  --region "$REGION" \
  --query 'builds[0].buildStatus' \
  --output text)

if [ "$BUILD_STATUS" != "SUCCEEDED" ]; then
  echo "Docker build failed with status: $BUILD_STATUS"
  exit 1
fi

echo "Docker build completed successfully!"

# Start content deployment
echo "Starting content deployment to EFS..."
CONTENT_BUILD_ID=$(aws codebuild start-build \
  --project-name "$CONTENT_DEPLOY_PROJECT" \
  --source-version "refs/heads/$GITHUB_BRANCH" \
  --region "$REGION" \
  --query 'build.id' \
  --output text)

echo "Content deployment started with ID: $CONTENT_BUILD_ID"

# Wait for content deployment to complete
echo "Waiting for content deployment to complete..."
aws codebuild wait build-completed --id "$CONTENT_BUILD_ID" --region "$REGION"

CONTENT_BUILD_STATUS=$(aws codebuild batch-get-builds \
  --ids "$CONTENT_BUILD_ID" \
  --region "$REGION" \
  --query 'builds[0].buildStatus' \
  --output text)

if [ "$CONTENT_BUILD_STATUS" != "SUCCEEDED" ]; then
  echo "Content deployment failed with status: $CONTENT_BUILD_STATUS"
  exit 1
fi

echo "Content deployment completed successfully!"

# Get the latest task definition
echo "Getting latest task definition..."
TASK_DEF_ARN=$(aws ecs describe-task-definition \
  --task-definition "${ENVIRONMENT}-drupal-app" \
  --region "$REGION" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Latest task definition: $TASK_DEF_ARN"

# Create CodeDeploy deployment
echo "Creating CodeDeploy deployment..."
DEPLOYMENT_ID=$(aws deploy create-deployment \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "${ENVIRONMENT}-drupal-deployment-group" \
  --revision '{
    "revisionType": "AppSpecContent",
    "appSpecContent": {
      "content": "{\"version\":0.0,\"Resources\":[{\"TargetService\":{\"Type\":\"AWS::ECS::Service\",\"Properties\":{\"TaskDefinition\":\"'$TASK_DEF_ARN'\",\"LoadBalancerInfo\":{\"ContainerName\":\"drupal-app\",\"ContainerPort\":80}}}}]}"
    }
  }' \
  --region "$REGION" \
  --query 'deploymentId' \
  --output text)

echo "CodeDeploy deployment created with ID: $DEPLOYMENT_ID"

# Wait for deployment to complete
echo "Waiting for deployment to complete..."
aws deploy wait deployment-successful --deployment-id "$DEPLOYMENT_ID" --region "$REGION"

DEPLOYMENT_STATUS=$(aws deploy get-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$REGION" \
  --query 'deploymentInfo.status' \
  --output text)

if [ "$DEPLOYMENT_STATUS" != "Succeeded" ]; then
  echo "Deployment failed with status: $DEPLOYMENT_STATUS"
  exit 1
fi

echo "Deployment completed successfully!"
echo "Your Drupal application is now deployed and available."