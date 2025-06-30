#!/bin/bash

# Generate buildspec.yml dynamically to avoid YAML encoding issues
cat > buildspec.yml << 'EOF'
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region us-east-1 > /tmp/ecr_password
      - docker login --username AWS --password-stdin 396503876336.dkr.ecr.us-east-1.amazonaws.com/production-drupal < /tmp/ecr_password
      - REPOSITORY_URI=396503876336.dkr.ecr.us-east-1.amazonaws.com/production-drupal
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
      - echo "Repository URI: $REPOSITORY_URI"
      - echo "Image tag: $IMAGE_TAG"
  build:
    commands:
      - echo "Building the Docker image..."
      - docker build --platform linux/amd64 -t $REPOSITORY_URI:$IMAGE_TAG .
      - docker tag $REPOSITORY_URI:$IMAGE_TAG $REPOSITORY_URI:latest
      - echo "Pushing the Docker images..."
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - docker push $REPOSITORY_URI:latest
      - echo "Writing image definitions file..."
      - printf '{"ImageURI":"%s"}' $REPOSITORY_URI:$IMAGE_TAG > imageDefinitions.json
  post_build:
    commands:
      - echo "Build completed successfully"

artifacts:
  files:
    - imageDefinitions.json
    - appspec.yml
    - taskdef.json
EOF

echo "buildspec.yml generated successfully"