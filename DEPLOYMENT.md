# Deployment Guide

This guide explains the different ways to deploy your Drupal application and when to use each approach.

## Deployment Options Overview

### 1. Manual Deployment (Learning/Development)
**Best for**: Learning the architecture, development, testing
- Full control over each step
- Good for understanding how everything works
- Requires manual intervention for each deployment

### 2. GitHub Actions (Production)
**Best for**: Production environments, team collaboration
- Fully automated deployments
- Consistent deployment process
- Better for teams and production workloads

## Option 1: Manual Deployment

### Prerequisites
- AWS CLI configured
- Terraform installed
- Docker/Podman for local testing

### Step-by-Step Instructions

#### 1. Configure Environment
```bash
# Clone the repository
git clone <your-repo-url>
cd drupal-aws-app

# Configure Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region = "us-east-1"
environment = "production"

# Database passwords (use strong passwords)
db_password = "your-secure-password-here"
db_root_password = "your-secure-root-password-here"

# GitHub repository (for CodeBuild)
github_repository_url = "https://github.com/your-username/drupal-aws-app"
```

#### 2. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply
```

This creates:
- VPC with public/private subnets
- ECS cluster and service
- EFS file system
- ECR repository
- CodeBuild projects
- CodeDeploy application
- Application Load Balancer

#### 3. Deploy Application
```bash
# Go back to project root
cd ..

# Deploy Docker image and content
./scripts/deploy-docker.sh production us-east-1 main
```

This script:
1. Builds Docker image via CodeBuild
2. Deploys content to EFS
3. Deploys to ECS via CodeDeploy

#### 4. Access Your Application
```bash
cd terraform
terraform output app_url
```

### Manual Deployment Commands

#### Build Docker Image Only
```bash
aws codebuild start-build \
  --project-name production-drupal-docker-build \
  --region us-east-1
```

#### Deploy Content Only
```bash
aws codebuild start-build \
  --project-name production-drupal-content-deploy \
  --region us-east-1
```

#### Deploy to ECS Only
```bash
# Get latest task definition
TASK_DEF_ARN=$(aws ecs describe-task-definition \
  --task-definition production-drupal-app \
  --region us-east-1 \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

# Create deployment
aws deploy create-deployment \
  --application-name production-drupal-app \
  --deployment-group-name production-drupal-deployment-group \
  --revision '{
    "revisionType": "AppSpecContent",
    "appSpecContent": {
      "content": "{\"version\":0.0,\"Resources\":[{\"TargetService\":{\"Type\":\"AWS::ECS::Service\",\"Properties\":{\"TaskDefinition\":\"'$TASK_DEF_ARN'\",\"LoadBalancerInfo\":{\"ContainerName\":\"drupal-app\",\"ContainerPort\":80}}}}]}"
    }
  }' \
  --region us-east-1
```

## Option 2: GitHub Actions (Recommended for Production)

### Prerequisites
- GitHub repository
- AWS credentials
- Infrastructure already deployed

### Setup Instructions

#### 1. Set Up GitHub Secrets
1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add these secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

#### 2. Deploy Infrastructure (One-time)
```bash
cd terraform
terraform init
terraform apply
```

#### 3. Push Code to Trigger Deployment
```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

The GitHub Actions workflow will automatically:
1. Test the Docker build
2. Build and push Docker image to ECR
3. Deploy content to EFS
4. Deploy to ECS with blue-green strategy
5. Run health checks

### GitHub Actions Workflow

The workflow (`.github/workflows/deploy.yml`) includes:

1. **Test Job**: Builds Docker image to ensure it works
2. **Deploy Job**:
   - Builds Docker image via CodeBuild
   - Deploys content to EFS
   - Deploys to ECS via CodeDeploy
   - Runs health checks

### Triggering Deployments

#### Automatic Deployment
- Push to `main` or `production` branch
- Creates a pull request to `main`

#### Manual Deployment
1. Go to Actions tab in GitHub
2. Select "Deploy to AWS" workflow
3. Click "Run workflow"
4. Select branch and click "Run workflow"

## When to Use Each Option

### Use Manual Deployment When:
- Learning the architecture
- Development and testing
- Debugging deployment issues
- One-time deployments
- You want full control

### Use GitHub Actions When:
- Production environments
- Team collaboration
- Regular deployments
- You want automation
- Multiple developers

## Troubleshooting Deployments

### Manual Deployment Issues

#### CodeBuild Failures
```bash
# Check build status
aws codebuild batch-get-builds \
  --ids <build-id> \
  --region us-east-1

# View build logs
aws logs tail /aws/codebuild/production-drupal-docker-build --follow
```

#### CodeDeploy Failures
```bash
# Check deployment status
aws deploy get-deployment \
  --deployment-id <deployment-id> \
  --region us-east-1

# List recent deployments
aws deploy list-deployments \
  --application-name production-drupal-app \
  --deployment-group-name production-drupal-deployment-group \
  --region us-east-1
```

#### ECS Issues
```bash
# Check service status
aws ecs describe-services \
  --cluster production-drupal-cluster \
  --services production-drupal-service \
  --region us-east-1

# View task logs
aws logs tail /ecs/production-drupal-app --follow
```

### GitHub Actions Issues

#### Workflow Failures
1. Check the Actions tab in GitHub
2. Click on the failed workflow run
3. Review the logs for each step
4. Common issues:
   - AWS credentials not configured
   - Terraform state not initialized
   - CodeBuild project not found

#### Permission Issues
- Ensure AWS credentials have proper permissions
- Check that GitHub secrets are correctly set
- Verify repository access

## Best Practices

### Security
- Use strong database passwords
- Rotate AWS credentials regularly
- Enable CloudTrail for audit logging
- Use IAM roles with least privilege

### Monitoring
- Set up CloudWatch alarms
- Monitor ECS service metrics
- Check EFS performance
- Review CodeBuild logs regularly

### Backup
- Backup EFS data regularly
- Export database dumps
- Keep multiple Docker image versions
- Document deployment procedures

## Cost Optimization

### Manual Deployment
- Only pay for infrastructure when deployed
- Good for development/testing
- Can destroy infrastructure when not needed

### GitHub Actions
- Pay for build minutes used
- More efficient for regular deployments
- Better for production workloads

## Next Steps

After successful deployment:

1. **Configure Domain**: Set up custom domain with SSL
2. **Set Up Monitoring**: Configure CloudWatch alarms
3. **Backup Strategy**: Implement regular backups
4. **Security Hardening**: Review security configurations
5. **Performance Tuning**: Optimize for your workload

## Support

For deployment issues:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Check GitHub Actions logs (if using)
4. Verify AWS service quotas
5. Open an issue in the repository