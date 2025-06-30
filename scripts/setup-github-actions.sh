#!/bin/bash

# GitHub Actions AWS Setup Script
# This script creates the necessary AWS resources for GitHub Actions deployment

set -e

# Configuration
ENVIRONMENT=${1:-production}
REGION=${2:-us-east-1}
GITHUB_USERNAME=${3:-klchandrakanth}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up AWS resources for GitHub Actions...${NC}"

# Create IAM User for GitHub Actions
echo -e "${YELLOW}Creating IAM user for GitHub Actions...${NC}"
aws iam create-user --user-name github-actions-drupal

# Create access key for the user
echo -e "${YELLOW}Creating access key...${NC}"
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name github-actions-drupal)
ACCESS_KEY_ID=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.SecretAccessKey')

echo -e "${GREEN}Access Key created successfully!${NC}"
echo -e "${YELLOW}Access Key ID: $ACCESS_KEY_ID${NC}"
echo -e "${YELLOW}Secret Access Key: $SECRET_ACCESS_KEY${NC}"

# Create IAM Policy for GitHub Actions
echo -e "${YELLOW}Creating IAM policy for GitHub Actions...${NC}"
cat > /tmp/github-actions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:StartBuild",
        "codebuild:BatchGetBuilds"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeployment",
        "codedeploy:CreateDeployment",
        "codedeploy:GetApplication",
        "codedeploy:GetDeploymentGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/${ENVIRONMENT}-ecs-execution-role",
        "arn:aws:iam::*:role/${ENVIRONMENT}-ecs-task-role"
      ]
    }
  ]
}
EOF

# Attach policy to user
aws iam put-user-policy \
  --user-name github-actions-drupal \
  --policy-name github-actions-drupal-policy \
  --policy-document file:///tmp/github-actions-policy.json

echo -e "${GREEN}IAM policy attached successfully!${NC}"

# Clean up
rm -f /tmp/github-actions-policy.json

echo -e "${GREEN}✅ GitHub Actions AWS setup completed!${NC}"
echo -e "${YELLOW}📋 Next steps:${NC}"
echo -e "1. Add these secrets to your GitHub repository:"
echo -e "   - AWS_ACCESS_KEY_ID: $ACCESS_KEY_ID"
echo -e "   - AWS_SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY"
echo -e "   - AWS_REGION: $REGION"
echo -e ""
echo -e "2. Go to: https://github.com/klchandrakanth/drupal-aws-app/settings/secrets/actions"
echo -e ""
echo -e "3. Push a commit to trigger the GitHub Actions workflow:"
echo -e "   git commit --allow-empty -m 'Trigger GitHub Actions deployment'"
echo -e "   git push origin main"