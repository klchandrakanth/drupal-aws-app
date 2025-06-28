#!/bin/bash

# MariaDB Backup Script
# This script creates a backup of MariaDB data from EFS

set -e

# Configuration
ENVIRONMENT=${1:-production}
REGION=${2:-us-east-1}
BACKUP_DIR="/tmp/mariadb-backup-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting MariaDB backup...${NC}"

# Get EFS file system ID
EFS_ID=$(aws efs describe-file-systems \
  --region $REGION \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='${ENVIRONMENT}-drupal-content']].FileSystemId" \
  --output text)

if [ -z "$EFS_ID" ]; then
    echo -e "${RED}Error: Could not find EFS file system for environment: $ENVIRONMENT${NC}"
    exit 1
fi

echo -e "${YELLOW}EFS File System ID: $EFS_ID${NC}"

# Create backup directory
mkdir -p $BACKUP_DIR

# Get ECS task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster ${ENVIRONMENT}-drupal-cluster \
  --service-name ${ENVIRONMENT}-drupal-service \
  --region $REGION \
  --query 'taskArns[0]' \
  --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo -e "${RED}Error: No running ECS tasks found${NC}"
    exit 1
fi

echo -e "${YELLOW}ECS Task ARN: $TASK_ARN${NC}"

# Create a temporary ECS task to mount EFS and create backup
echo -e "${YELLOW}Creating backup task...${NC}"

# Create backup task definition
cat > /tmp/backup-task-definition.json << EOF
{
  "family": "${ENVIRONMENT}-mariadb-backup",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/${ENVIRONMENT}-ecs-execution-role",
  "containerDefinitions": [
    {
      "name": "backup",
      "image": "alpine:latest",
      "command": [
        "sh", "-c",
        "apk add --no-cache rsync && rsync -av /mariadb-data/ /backup/ && echo 'Backup completed'"
      ],
      "mountPoints": [
        {
          "sourceVolume": "mariadb-data",
          "containerPath": "/mariadb-data",
          "readOnly": true
        },
        {
          "sourceVolume": "backup",
          "containerPath": "/backup",
          "readOnly": false
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${ENVIRONMENT}-mariadb-backup",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "volumes": [
    {
      "name": "mariadb-data",
      "efsVolumeConfiguration": {
        "fileSystemId": "${EFS_ID}",
        "rootDirectory": "/mariadb",
        "transitEncryption": "ENABLED",
        "transitEncryptionPort": 2049,
        "authorizationConfig": {
          "accessPointId": "$(aws efs describe-access-points --file-system-id $EFS_ID --query 'AccessPoints[?Tags[?Key==\`Name\` && Value==\`${ENVIRONMENT}-mariadb-data-access-point\`]].AccessPointId' --output text)",
          "iam": "ENABLED"
        }
      }
    },
    {
      "name": "backup",
      "efsVolumeConfiguration": {
        "fileSystemId": "${EFS_ID}",
        "rootDirectory": "/backup",
        "transitEncryption": "ENABLED",
        "transitEncryptionPort": 2049,
        "authorizationConfig": {
          "accessPointId": "$(aws efs describe-access-points --file-system-id $EFS_ID --query 'AccessPoints[?Tags[?Key==\`Name\` && Value==\`${ENVIRONMENT}-drupal-content-access-point\`]].AccessPointId' --output text)",
          "iam": "ENABLED"
        }
      }
    }
  ]
}
EOF

# Register task definition
aws ecs register-task-definition \
  --cli-input-json file:///tmp/backup-task-definition.json \
  --region $REGION

# Get subnet and security group
SUBNET_ID=$(aws ecs describe-tasks \
  --cluster ${ENVIRONMENT}-drupal-cluster \
  --tasks $TASK_ARN \
  --region $REGION \
  --query 'tasks[0].attachments[0].details[?name==`subnetId`].value' \
  --output text)

SECURITY_GROUP_ID=$(aws ecs describe-tasks \
  --cluster ${ENVIRONMENT}-drupal-cluster \
  --tasks $TASK_ARN \
  --region $REGION \
  --query 'tasks[0].attachments[0].details[?name==`securityGroups`].value' \
  --output text)

# Run backup task
echo -e "${YELLOW}Running backup task...${NC}"

BACKUP_TASK_ARN=$(aws ecs run-task \
  --cluster ${ENVIRONMENT}-drupal-cluster \
  --task-definition ${ENVIRONMENT}-mariadb-backup \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=DISABLED}" \
  --region $REGION \
  --query 'tasks[0].taskArn' \
  --output text)

echo -e "${YELLOW}Backup task ARN: $BACKUP_TASK_ARN${NC}"

# Wait for task to complete
echo -e "${YELLOW}Waiting for backup to complete...${NC}"
aws ecs wait tasks-stopped \
  --cluster ${ENVIRONMENT}-drupal-cluster \
  --tasks $BACKUP_TASK_ARN \
  --region $REGION

# Check task status
TASK_STATUS=$(aws ecs describe-tasks \
  --cluster ${ENVIRONMENT}-drupal-cluster \
  --tasks $BACKUP_TASK_ARN \
  --region $REGION \
  --query 'tasks[0].lastStatus' \
  --output text)

if [ "$TASK_STATUS" = "STOPPED" ]; then
    EXIT_CODE=$(aws ecs describe-tasks \
      --cluster ${ENVIRONMENT}-drupal-cluster \
      --tasks $BACKUP_TASK_ARN \
      --region $REGION \
      --query 'tasks[0].containers[0].exitCode' \
      --output text)

    if [ "$EXIT_CODE" = "0" ]; then
        echo -e "${GREEN}Backup completed successfully!${NC}"
        echo -e "${YELLOW}Backup location: EFS /backup directory${NC}"
    else
        echo -e "${RED}Backup failed with exit code: $EXIT_CODE${NC}"
        exit 1
    fi
else
    echo -e "${RED}Backup task did not complete properly${NC}"
    exit 1
fi

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
rm -f /tmp/backup-task-definition.json

echo -e "${GREEN}MariaDB backup process completed!${NC}"
echo -e "${YELLOW}To restore:${NC}"
echo -e "1. Stop the main ECS service"
echo -e "2. Copy data from /backup to /mariadb in EFS"
echo -e "3. Restart the ECS service"