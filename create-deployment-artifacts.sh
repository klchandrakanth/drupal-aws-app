#!/bin/bash

# Get the task definition ARN
TASKDEF_ARN=$(aws ecs describe-task-definition --task-definition production-drupal-app --region us-east-1 --query 'taskDefinition.taskDefinitionArn' --output text)
echo "Task Definition ARN: $TASKDEF_ARN"

# Create appspec.yml
echo "Creating appspec.yml..."
cat > appspec.yml << EOF
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: $TASKDEF_ARN
        LoadBalancerInfo:
          ContainerName: "drupal-app"
          ContainerPort: 80
EOF

# Get current task definition and modify it
echo "Creating taskdef.json..."
aws ecs describe-task-definition --task-definition production-drupal-app --region us-east-1 --query 'taskDefinition' > taskdef.json

# Remove MariaDB EFS volume
echo "Removing MariaDB EFS volume from task definition..."
jq 'del(.volumes[] | select(.name == "mariadb-data"))' taskdef.json > taskdef_temp.json
jq 'del(.containerDefinitions[0].mountPoints[] | select(.sourceVolume == "mariadb-data"))' taskdef_temp.json > taskdef.json

# Update the image
REPOSITORY_URI="396503876336.dkr.ecr.us-east-1.amazonaws.com/production-drupal"
IMAGE_TAG="latest"
jq --arg img "$REPOSITORY_URI:$IMAGE_TAG" '.containerDefinitions[1].image = $img' taskdef.json > taskdef_temp.json
mv taskdef_temp.json taskdef.json

# Create imageDefinitions.json
printf '{"ImageURI":"%s"}' "$REPOSITORY_URI:$IMAGE_TAG" > imageDefinitions.json

# Upload to S3
echo "Uploading artifacts to S3..."
aws s3 cp appspec.yml s3://production-drupal-codebuild-artifacts-lwouy9p2/production-drupal-docker-build/appspec.yml
aws s3 cp taskdef.json s3://production-drupal-codebuild-artifacts-lwouy9p2/production-drupal-docker-build/taskdef.json
aws s3 cp imageDefinitions.json s3://production-drupal-codebuild-artifacts-lwouy9p2/production-drupal-docker-build/imageDefinitions.json

echo "Deployment artifacts created and uploaded successfully!"