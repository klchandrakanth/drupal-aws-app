# Drupal AWS Application - ECS with MariaDB and EFS

This project deploys a Drupal application on AWS using ECS Fargate with MariaDB containers, EFS for content storage, and a complete CI/CD pipeline with CodeBuild and CodeDeploy.

## Architecture Overview

### Components

1. **ECS Fargate Cluster** - Runs Drupal and MariaDB containers
2. **EFS (Elastic File System)** - Persistent storage for Drupal content
3. **ECR (Elastic Container Registry)** - Docker image repository
4. **CodeBuild** - Builds Docker images and deploys content
5. **CodeDeploy** - Deploys application updates to ECS
6. **Application Load Balancer** - Routes traffic to ECS services
7. **VPC with Public/Private Subnets** - Network isolation

### Key Features

- **Containerized MariaDB** - No RDS dependency, runs alongside Drupal
- **EFS Content Storage** - Persistent, scalable file storage
- **CI/CD Pipeline** - Automated builds and deployments
- **Blue-Green Deployments** - Zero-downtime deployments
- **Auto Scaling** - Handles traffic spikes automatically

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Docker and Podman (for local testing)
- GitHub repository with your code

## Quick Start

### 1. Configure Variables

Copy the example variables file and update it:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region = "us-east-1"
environment = "production"

# Database passwords (use strong passwords)
db_password = "your-secure-password-here"
db_root_password = "your-secure-root-password-here"

# GitHub repository
github_repository_url = "https://github.com/your-username/drupal-aws-app"
```

### 2. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Deploy Application

```bash
# Deploy Docker image and content
./scripts/deploy-docker.sh production us-east-1 main
```

### 4. Access Your Application

Get the ALB DNS name from Terraform outputs:

```bash
terraform output app_url
```

## Local Development

### Running with Podman

```bash
# Build and run locally
./run-local-podman.sh

# Access at http://localhost:8080
```

### Testing Changes

1. Make changes to your code
2. Test locally with Podman
3. Commit and push to GitHub
4. Deploy to AWS using the deployment script

## CI/CD Pipeline

### CodeBuild Projects

1. **Docker Build Project** - Builds and pushes Docker images to ECR
2. **Content Deploy Project** - Deploys static content to EFS

### CodeDeploy

- Deploys new Docker images to ECS
- Uses blue-green deployment strategy
- Zero-downtime deployments

### Deployment Process

1. **Code Changes** → Push to GitHub
2. **CodeBuild** → Build Docker image and deploy content
3. **CodeDeploy** → Deploy to ECS with blue-green strategy
4. **Health Checks** → Verify deployment success

## Content Management

### EFS Structure

```
/var/www/html/web/sites/default/files/
├── files/          # Public files
└── private/        # Private files
```

### Adding Content

1. Place files in the `content/` directory
2. Run content deployment:
   ```bash
   aws codebuild start-build --project-name production-drupal-content-deploy
   ```

### Content Types

- **Public Files** - Images, documents, videos
- **Private Files** - User uploads, sensitive documents

## Monitoring and Logs

### CloudWatch Logs

- ECS Application Logs: `/ecs/production-drupal-app`
- ECS MariaDB Logs: `/ecs/production-drupal-mariadb`
- CodeBuild Logs: Available in S3 and CloudWatch

### Health Checks

- Application: HTTP health check on port 80
- Database: MySQL ping health check
- Load Balancer: HTTP health check on `/`

## Scaling

### Auto Scaling

ECS service automatically scales based on:
- CPU utilization
- Memory utilization
- Custom CloudWatch metrics

### Manual Scaling

```bash
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 4
```

## Security

### Network Security

- VPC with public/private subnets
- Security groups for each component
- EFS access via IAM roles

### Data Security

- EFS encryption at rest
- EFS encryption in transit
- Database encryption
- HTTPS/TLS for web traffic

### IAM Roles

- ECS Execution Role - Pulls images and writes logs
- ECS Task Role - Accesses EFS and other AWS services
- CodeBuild Role - Builds and pushes images
- CodeDeploy Role - Deploys to ECS

## Troubleshooting

### Common Issues

1. **Container Health Check Failures**
   - Check application logs in CloudWatch
   - Verify database connectivity
   - Check EFS mount permissions

2. **Deployment Failures**
   - Check CodeBuild logs
   - Verify ECR repository access
   - Check CodeDeploy deployment status

3. **Content Not Updating**
   - Verify EFS mount in container
   - Check content deployment logs
   - Verify file permissions

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster production-drupal-cluster \
  --services production-drupal-service

# View application logs
aws logs tail /ecs/production-drupal-app --follow

# Check EFS mount
aws efs describe-file-systems

# List CodeBuild projects
aws codebuild list-projects
```

## Cost Optimization

### Recommendations

1. **Use Spot Instances** - For non-critical workloads
2. **Right-size Resources** - Monitor CPU/memory usage
3. **EFS Lifecycle Management** - Move old files to IA storage
4. **Clean up unused resources** - Regular cleanup of old images

### Estimated Costs (us-east-1)

- ECS Fargate: ~$50-100/month (2 tasks)
- EFS: ~$10-20/month
- ALB: ~$20/month
- CodeBuild/CodeDeploy: ~$5-10/month
- **Total: ~$85-130/month**

## Support

For issues and questions:
1. Check CloudWatch logs
2. Review Terraform outputs
3. Verify AWS service quotas
4. Check security group configurations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes locally
4. Submit a pull request

## License

This project is licensed under the MIT License.