# Drupal AWS Application

A production-ready Drupal application deployed on AWS using serverless architecture with ECS Fargate, containerized MariaDB, and EFS for persistent storage.

## Architecture Overview

This application uses a modern, scalable architecture:

- **ECS Fargate**: Serverless container orchestration
- **MariaDB Container**: Database running alongside Drupal (no RDS dependency)
- **EFS (Elastic File System)**: Persistent storage for Drupal content
- **ECR (Elastic Container Registry)**: Docker image repository
- **Application Load Balancer**: High availability and traffic distribution
- **VPC with Public/Private Subnets**: Secure network architecture
- **CloudWatch**: Monitoring and logging
- **CodeBuild & CodeDeploy**: CI/CD pipeline for automated deployments
- **Auto Scaling**: Automatic scaling based on demand

## Key Features

- ✅ **Drupal 10** with PHP 8.1
- ✅ **Containerized MariaDB** - No RDS costs or complexity
- ✅ **EFS Content Storage** - Persistent, scalable file storage
- ✅ **SSL/HTTPS support** (ports 80 and 443)
- ✅ **Production-ready Docker configuration**
- ✅ **Automated deployment with Terraform**
- ✅ **High availability across multiple AZs**
- ✅ **CloudWatch monitoring and alerting**
- ✅ **CI/CD Pipeline** - Automated builds and deployments
- ✅ **Blue-Green Deployments** - Zero-downtime updates
- ✅ **Health checks and auto-recovery**

## Deployment Options

### Option 1: Manual Deployment (Recommended for learning)
- Deploy infrastructure with Terraform
- Build and deploy manually using scripts
- Full control over the deployment process
- Good for understanding the architecture

### Option 2: GitHub Actions (Recommended for production)
- Automated deployments on code changes
- No manual intervention required
- Consistent deployment process
- Better for team collaboration

**Why GitHub Actions?**
- **Automation**: Deploy automatically when you push code
- **Consistency**: Same deployment process every time
- **Team Collaboration**: Multiple developers can deploy safely
- **Audit Trail**: Track all deployments in GitHub
- **Rollback**: Easy to revert to previous versions

## Prerequisites

Before deploying this application, ensure you have:

1. **AWS CLI** installed and configured with appropriate permissions
2. **Docker** and **Podman** installed for local testing
3. **Terraform** (version >= 1.0) installed
4. **GitHub repository** (for automated deployments)
5. **AWS Account** with permissions for:
   - ECS
   - EFS
   - ECR
   - VPC
   - Application Load Balancer
   - CloudWatch
   - CodeBuild
   - CodeDeploy
   - IAM

## Quick Start Guide

### Step 1: Clone and Setup

```bash
git clone <your-repo-url>
cd drupal-aws-app
```

### Step 2: Configure Variables

Copy the example configuration and update it with your values:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:
```hcl
aws_region = "us-east-1"
environment = "production"

# Database passwords (use strong passwords)
db_password = "your-secure-password-here"
db_root_password = "your-secure-root-password-here"

# GitHub repository (for CI/CD)
github_repository_url = "https://github.com/your-username/drupal-aws-app"
```

### Step 3: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 4: Deploy Application

#### Option A: Manual Deployment
```bash
# Deploy Docker image and content
./scripts/deploy-docker.sh production us-east-1 main
```

#### Option B: GitHub Actions (Recommended)
1. **Set up GitHub Secrets**:
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add these secrets:
     - `AWS_ACCESS_KEY_ID`: Your AWS access key
     - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

2. **Push to trigger deployment**:
   ```bash
   git add .
   git commit -m "Initial deployment"
   git push origin main
   ```

### Step 5: Access Your Application

Get the application URL:
```bash
cd terraform
terraform output app_url
```

## Local Development

### Using Podman (Recommended)

For local development and testing:

```bash
# Build and run locally
./run-local-podman.sh

# Access at http://localhost:8080
```

### Using Docker Compose

```bash
cd drupal-aws-app
docker-compose up -d
```

Access the application at:
- HTTP: http://localhost:8080
- HTTPS: https://localhost:8443

## Infrastructure Components

### VPC and Networking
- **VPC**: Custom VPC with CIDR `10.0.0.0/16`
- **Public Subnets**: For ALB and NAT Gateway
- **Private Subnets**: For ECS tasks
- **Security Groups**: Properly configured for each component

### ECS Fargate
- **Cluster**: `production-drupal-cluster`
- **Service**: `production-drupal-service`
- **Task Definition**: Multi-container with Drupal + MariaDB
- **Auto Scaling**: Based on CPU and memory utilization

### MariaDB Container
- **Image**: mariadb:10.6
- **Storage**: Container storage (no RDS costs)
- **Backup**: Manual backups via ECS task snapshots
- **Scaling**: Scales with ECS tasks
- **Data Persistence**: ✅ **Survives Fargate Spot interruptions**

### EFS (Elastic File System)
- **Purpose**: Persistent storage for Drupal content
- **Encryption**: At rest and in transit
- **Access Points**: IAM-based access control
- **Mount Points**: `/var/www/html/web/sites/default/files`

### ECR (Elastic Container Registry)
- **Repository**: `production-drupal`
- **Lifecycle Policy**: Keep last 5 images
- **Scanning**: Automatic vulnerability scanning

### Application Load Balancer
- **Type**: Application Load Balancer
- **Protocols**: HTTP (80) and HTTPS (443)
- **Health Checks**: Configured for Drupal
- **Target Groups**: IP-based targeting for Fargate

### CI/CD Pipeline
- **CodeBuild**: Builds Docker images and deploys content
- **CodeDeploy**: Blue-green deployments to ECS
- **GitHub Actions**: Automated workflow (optional)

### CloudWatch
- **Logs**: Application and infrastructure logs
- **Metrics**: CPU, memory, and ALB metrics
- **Dashboard**: Pre-configured monitoring dashboard
- **Alarms**: CPU and memory alarms

## Content Management

### EFS Structure
```
/var/www/html/web/sites/default/files/
├── files/          # Public files
└── private/        # Private files
```

### Adding Content
1. Place files in the `content/` directory
2. Deploy content:
   ```bash
   # Manual deployment
   aws codebuild start-build --project-name production-drupal-content-deploy

   # Or push to GitHub (if using GitHub Actions)
   git add content/
   git commit -m "Add new content"
   git push origin main
   ```

## Data Persistence and Backup

### MariaDB Data Persistence

**✅ Your MariaDB data is now persistent!** When using Fargate Spot, your database data will survive task restarts.

#### How It Works
- **EFS Volume**: MariaDB data is stored in EFS at `/mariadb` directory
- **Access Point**: Dedicated EFS access point with proper permissions (UID/GID 999)
- **Automatic Mounting**: Data is automatically mounted to `/var/lib/mysql` in the container
- **Encryption**: Data is encrypted at rest and in transit

#### EFS Structure for Data
```
EFS File System
├── /drupal-content/     # Drupal files (existing)
└── /mariadb/           # MariaDB data (new)
    ├── mysql/          # Database files
    ├── performance_schema/
    └── ...
```

### Backup Solutions

#### Option 1: Automated Backup Script
```bash
# Create a backup of MariaDB data
./scripts/backup-mariadb.sh production us-east-1

# Backup will be stored in EFS /backup directory
```

#### Option 2: Manual Backup via ECS Task
```bash
# Stop the service temporarily
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 0

# Create backup (data remains in EFS)
# Restart service
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 1
```

#### Option 3: EFS Snapshot
```bash
# Create EFS snapshot (includes both Drupal and MariaDB data)
aws efs create-snapshot \
  --file-system-id fs-xxxxxxxxx \
  --description "Drupal and MariaDB backup $(date)"
```

### Restore Process

#### From Backup Script
```bash
# 1. Stop the ECS service
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 0

# 2. Copy backup data back to MariaDB directory
# (Use ECS task or EFS mount)

# 3. Restart the service
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 1
```

#### From EFS Snapshot
```bash
# 1. Create new EFS from snapshot
aws efs create-file-system \
  --creation-token restored-drupal \
  --encrypted \
  --source-snapshot-id snap-xxxxxxxxx

# 2. Update ECS task definition to use new EFS
# 3. Redeploy the service
```

### Monitoring Data Persistence

#### Check EFS Usage
```bash
# Monitor EFS storage usage
aws efs describe-file-systems \
  --query 'FileSystems[0].{SizeInBytes:SizeInBytes,NumberOfMountTargets:NumberOfMountTargets}'

# Check MariaDB data directory size
aws efs describe-access-points \
  --file-system-id fs-xxxxxxxxx
```

#### Verify Data Persistence
```bash
# Check if MariaDB data is being written to EFS
aws logs tail /ecs/production-drupal-mariadb --follow

# Look for messages like:
# "InnoDB: Database was not shut down normally"
# "InnoDB: Starting recovery from checkpoint"
```

### Best Practices

#### Backup Schedule
- **Daily**: Automated backup script
- **Weekly**: EFS snapshot
- **Before Updates**: Manual backup

#### Data Integrity
- **Health Checks**: MariaDB container has health checks
- **Graceful Shutdown**: Containers shut down gracefully
- **Transaction Logs**: MariaDB maintains transaction logs

#### Cost Considerations
- **EFS Storage**: ~$0.30/GB/month
- **Backup Storage**: Additional EFS usage
- **Snapshot Storage**: ~$0.05/GB/month

## Security Features

- **VPC Isolation**: Private subnets for sensitive resources
- **Security Groups**: Restrictive access controls
- **SSL/TLS**: HTTPS support with self-signed certificates
- **IAM Roles**: Least privilege access for all services
- **EFS Encryption**: At rest and in transit
- **Container Security**: Non-root user, minimal attack surface

## Monitoring and Logs

### CloudWatch Dashboard
Access the monitoring dashboard in AWS Console:
- ECS service metrics (CPU, Memory)
- ALB metrics (Request count, Response time)
- EFS metrics (Throughput, IOPS)
- Application error logs

### Logs
- **Application Logs**: `/ecs/production-drupal-app`
- **Database Logs**: `/ecs/production-drupal-mariadb`
- **CodeBuild Logs**: Available in S3 and CloudWatch
- **Access Logs**: ALB access logs

## Scaling

The application is designed to scale automatically:

- **ECS Auto Scaling**: Based on CPU and memory utilization
- **EFS Auto Scaling**: Automatically scales storage
- **ALB**: Distributes traffic across multiple instances
- **Container Scaling**: MariaDB scales with Drupal containers

## Cost Optimization

- **No RDS Costs**: Using containerized MariaDB
- **Fargate Spot**: Can be enabled for cost savings
- **EFS Lifecycle Management**: Move old files to IA storage
- **CloudWatch Logs**: 7-day retention to reduce costs
- **Auto Scaling**: Scale down during low usage

## Troubleshooting

### Common Issues

1. **ECS Tasks Not Starting**
   - Check CloudWatch logs
   - Verify security group rules
   - Ensure EFS is accessible

2. **Database Connection Issues**
   - Verify MariaDB container is healthy
   - Check container networking
   - Review ECS task logs

3. **Content Not Persisting**
   - Verify EFS mount in container
   - Check EFS access point permissions
   - Review content deployment logs

4. **Deployment Failures**
   - Check CodeBuild logs
   - Verify ECR repository access
   - Review CodeDeploy deployment status

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

## Cost Estimation (us-east-1) - Cost-Optimized Configuration

### **Deployment Environment (1 task + Fargate Spot)**
- **ECS Fargate Spot**: ~$0.65/day (1 task, 60-70% savings)
- **EFS**: ~$0.01/day
- **ALB**: ~$0.54/day
- **CodeBuild/CodeDeploy**: ~$0.05/day (when deploying)
- **ECR**: ~$0.02/day
- **NAT Gateway**: ~$1.08/day
- **CloudWatch**: ~$0.02/day
- **Total**: ~$2.37/day = **~$71/month**

### **Production Environment (2 tasks + On-Demand)**
- **ECS Fargate**: ~$2.16/day (2 tasks)
- **EFS**: ~$0.01/day
- **ALB**: ~$0.54/day
- **CodeBuild/CodeDeploy**: ~$0.05/day
- **ECR**: ~$0.02/day
- **NAT Gateway**: ~$1.08/day
- **CloudWatch**: ~$0.02/day
- **Total**: ~$3.88/day = **~$116/month**

### **Cost Optimization Features**
- ✅ **Fargate Spot**: 60-70% cost savings on compute
- ✅ **Single Task**: Reduced from 2 to 1 task for deployment
- ✅ **Auto Scaling**: Can scale up when needed
- ✅ **No RDS**: Containerized MariaDB saves ~$13/month

## Support

For issues and questions:
1. Check CloudWatch logs
2. Review Terraform outputs
3. Verify AWS service quotas
4. Check security group configurations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes locally with Podman
4. Submit a pull request

## License

This project is licensed under the MIT License.