# Cost Optimization Guide

This guide shows how to optimize costs for your Drupal AWS deployment, especially for development and deployment environments.

## Current Cost-Optimized Configuration

### **Deployment Environment Settings**
- **ECS Tasks**: 1 task (reduced from 2)
- **Capacity Provider**: Fargate Spot (60-70% savings)
- **Auto Scaling**: Enabled (can scale up when needed)
- **Database**: Containerized MariaDB with **EFS persistence** (no RDS costs)
- **Data Persistence**: ✅ **Survives Fargate Spot interruptions**

### **Daily Cost Breakdown**
| Component | Cost/Day | Notes |
|-----------|----------|-------|
| ECS Fargate Spot (1 task) | $0.65 | 60-70% savings vs On-Demand |
| EFS Storage | $0.01 | Minimal usage |
| Application Load Balancer | $0.54 | Fixed cost |
| NAT Gateway | $1.08 | Network connectivity |
| CodeBuild/CodeDeploy | $0.05 | Only when deploying |
| ECR Registry | $0.02 | Minimal storage |
| CloudWatch | $0.02 | Basic monitoring |
| **TOTAL** | **$2.37/day** | **~$71/month** |

## Cost Comparison

### **Deployment vs Production**

| Environment | Tasks | Capacity | Daily Cost | Monthly Cost |
|-------------|-------|----------|------------|--------------|
| **Deployment** | 1 | Fargate Spot | $2.37 | $71 |
| **Production** | 2 | On-Demand | $3.88 | $116 |
| **Savings** | - | - | **$1.51/day** | **$45/month** |

### **vs Traditional RDS Setup**

| Architecture | Monthly Cost | Savings |
|--------------|--------------|---------|
| **Current (Containerized DB)** | $71 | - |
| **With RDS (db.t3.micro)** | $84 | -$13 |
| **Traditional RDS Setup** | $129 | -$58 |

## Data Persistence Benefits

### **Fargate Spot with Data Persistence**

**✅ Major Advantage**: Your MariaDB data now survives Fargate Spot interruptions!

#### Before (Ephemeral Storage)
- ❌ **Data Loss**: MariaDB data lost on task restart
- ❌ **Downtime**: Manual database restoration required
- ❌ **Risk**: Potential data corruption

#### After (EFS Persistence)
- ✅ **Data Survival**: MariaDB data persists through restarts
- ✅ **Zero Downtime**: Automatic recovery on restart
- ✅ **Reliability**: Transaction-safe database operations
- ✅ **Cost Savings**: Still using Fargate Spot (60-70% savings)

#### Cost Impact
- **EFS Storage**: ~$0.01/day (minimal for MariaDB data)
- **Total Cost**: Still ~$71/month
- **Benefit**: Production-grade reliability at development cost

### **Backup Strategy**
- **Automated Backups**: Included backup script
- **EFS Snapshots**: Point-in-time recovery
- **No Additional Cost**: Uses existing EFS infrastructure

## Additional Cost Optimization Options

### **1. Remove NAT Gateway (Development Only)**

**Warning**: This breaks internet access for containers but saves $1.08/day.

```bash
# Only use if containers don't need internet access
# Update VPC configuration to remove NAT Gateway
```

**Savings**: $32/month

### **2. Use Single AZ (Development)**

```bash
# Update availability_zones in terraform.tfvars
availability_zones = ["us-east-1a"]  # Single AZ
```

**Savings**: ~$10-15/month (reduced data transfer)

### **3. Reduce EFS Storage**

```bash
# Monitor EFS usage
aws efs describe-file-systems --query 'FileSystems[0].SizeInBytes'

# Clean up unused files
aws efs describe-access-points
```

### **4. Optimize CloudWatch Logs**

```bash
# Reduce log retention (default is 7 days)
# Update in terraform/modules/ecs/main.tf
retention_in_days = 3  # Instead of 7
```

**Savings**: ~$5-10/month

## Scaling for Different Workloads

### **Development/Testing**
```bash
# 1 task, Fargate Spot
app_count = 1
# Use capacity_provider_strategy with FARGATE_SPOT
```

**Cost**: ~$71/month

### **Staging/Pre-production**
```bash
# 1 task, On-Demand (more stable)
app_count = 1
# Remove capacity_provider_strategy for stability
```

**Cost**: ~$85/month

### **Production**
```bash
# 2 tasks, On-Demand
app_count = 2
# Use capacity_provider_strategy with FARGATE
```

**Cost**: ~$116/month

## Monitoring Costs

### **Set Up Cost Alerts**

```bash
# Create CloudWatch alarm for costs
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorType": "DIMENSIONAL",
    "DimensionalValueCount": 10
  }'

# Set up billing alerts in AWS Console
# Go to Billing → Billing Preferences → Billing Alerts
```

### **Track Usage**

```bash
# Check ECS usage
aws ecs describe-services \
  --cluster production-drupal-cluster \
  --services production-drupal-service

# Check EFS usage
aws efs describe-file-systems

# Check ECR storage
aws ecr describe-repositories
```

## Cost Optimization Commands

### **Scale Down for Development**
```bash
# Scale to 1 task
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 1

# Switch to Fargate Spot
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=1
```

### **Scale Up for Production**
```bash
# Scale to 2 tasks
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 2

# Switch to On-Demand for stability
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

### **Clean Up Unused Resources**
```bash
# List unused ECR images
aws ecr list-images \
  --repository-name production-drupal \
  --filter tagStatus=UNTAGGED

# Delete old images
aws ecr batch-delete-image \
  --repository-name production-drupal \
  --image-ids imageTag=old-tag

# Clean up EFS (if needed)
# Mount EFS and remove unused files
```

## Best Practices

### **Development Environment**
- Use 1 task with Fargate Spot
- Enable auto-scaling for spikes
- Monitor costs with CloudWatch
- Clean up unused resources regularly

### **Production Environment**
- Use 2 tasks with On-Demand for stability
- Set up cost alerts
- Monitor performance and scale accordingly
- Regular backup and maintenance

### **Cost Monitoring**
- Set up monthly budget alerts
- Monitor usage patterns
- Review costs weekly
- Optimize based on actual usage

## Emergency Cost Reduction

If you need to reduce costs immediately:

```bash
# 1. Scale down to 1 task
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --desired-count 1

# 2. Switch to Fargate Spot
aws ecs update-service \
  --cluster production-drupal-cluster \
  --service production-drupal-service \
  --capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=1

# 3. Reduce EFS storage (if possible)
# 4. Clean up unused ECR images
# 5. Reduce CloudWatch log retention
```

**Immediate Savings**: ~$45/month

## Summary

The current configuration is already optimized for cost:

- ✅ **Fargate Spot**: 60-70% savings on compute
- ✅ **Single Task**: Reduced from 2 to 1
- ✅ **Containerized DB**: No RDS costs
- ✅ **Auto Scaling**: Scale up when needed

**Total Cost**: ~$71/month for deployment environment

This provides a good balance between cost and functionality for development and deployment scenarios.