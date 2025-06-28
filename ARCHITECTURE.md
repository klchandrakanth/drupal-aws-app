# Architecture Documentation

## Overview

This Drupal application is deployed using a modern, scalable, and secure architecture on AWS. The design follows AWS best practices for production workloads with high availability, security, and cost optimization.

## Architecture Diagram

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Route 53 (Optional)                      │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │   HTTP (80)     │  │  HTTPS (443)    │  │ Health Check│  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                        VPC                                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  Public Subnets                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   AZ-1a     │  │   AZ-1b     │  │   AZ-1c     │     │ │
│  │  │   NAT GW    │  │             │  │             │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Private Subnets                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   AZ-1a     │  │   AZ-1b     │  │   AZ-1c     │     │ │
│  │  │ ECS Tasks   │  │ ECS Tasks   │  │ ECS Tasks   │     │ │
│  │  │   RDS       │  │             │  │             │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    ECS Fargate                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Drupal Container                           │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │  PHP 8.2 + Apache + Drupal 10                       │ │ │
│  │  │  - Port 80 (HTTP)                                   │ │ │
│  │  │  - Port 443 (HTTPS)                                 │ │ │
│  │  │  - Health Checks                                    │ │ │
│  │  │  - Auto Scaling                                     │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    RDS MySQL 8.0                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  - Multi-AZ Deployment                                 │ │
│  │  - Automated Backups                                   │ │
│  │  - Encryption at Rest                                  │ │
│  │  - Performance Insights                                │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                   CloudWatch                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  - Application Logs                                    │ │
│  │  - Infrastructure Metrics                              │ │
│  │  - Custom Dashboards                                   │ │
│  │  - Alarms & Notifications                              │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Application Load Balancer (ALB)

**Purpose**: Distributes incoming traffic across multiple ECS tasks and provides SSL termination.

**Features**:
- **Protocols**: HTTP (80) and HTTPS (443)
- **Health Checks**: Configured to check `/` endpoint
- **Target Groups**: IP-based targeting for Fargate tasks
- **Auto Scaling**: Integrates with ECS auto scaling
- **Security**: WAF-ready for additional protection

**Configuration**:
```hcl
resource "aws_lb" "main" {
  name               = "${var.environment}-drupal-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_groups
  subnets            = var.public_subnet_ids
}
```

### 2. VPC and Networking

**Purpose**: Provides isolated network environment with proper security controls.

**Components**:
- **VPC**: CIDR `10.0.0.0/16`
- **Public Subnets**: For ALB and NAT Gateway
- **Private Subnets**: For ECS tasks and RDS
- **Internet Gateway**: For public internet access
- **NAT Gateway**: For private subnet internet access
- **Route Tables**: Proper routing configuration

**Security Groups**:
- **ALB SG**: Allows HTTP/HTTPS from internet
- **App SG**: Allows traffic from ALB only
- **RDS SG**: Allows MySQL from App SG only

### 3. ECS Fargate

**Purpose**: Serverless container orchestration for the Drupal application.

**Features**:
- **Serverless**: No EC2 instances to manage
- **Auto Scaling**: Based on CPU and memory utilization
- **High Availability**: Tasks distributed across AZs
- **Health Checks**: Container-level health monitoring
- **Logging**: Integrated with CloudWatch Logs

**Task Definition**:
```json
{
  "family": "production-drupal-app",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": 256,
  "memory": 512,
  "executionRoleArn": "arn:aws:iam::...",
  "containerDefinitions": [...]
}
```

### 4. RDS MySQL

**Purpose**: Managed database service for Drupal content and configuration.

**Features**:
- **Engine**: MySQL 8.0
- **Instance**: db.t3.micro (scalable)
- **Storage**: 20GB GP2 with auto-scaling
- **Backup**: 7-day retention
- **Encryption**: Storage encryption enabled
- **Multi-AZ**: For high availability

**Configuration**:
```hcl
resource "aws_db_instance" "main" {
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true
  backup_retention_period = 7
}
```

### 5. CloudWatch

**Purpose**: Monitoring, logging, and alerting for the entire infrastructure.

**Components**:
- **Log Groups**: Application and infrastructure logs
- **Metrics**: CPU, memory, database, ALB metrics
- **Dashboard**: Pre-configured monitoring dashboard
- **Alarms**: Automated alerting for issues

## Data Flow

### 1. Incoming Request Flow

```
Internet → Route 53 → ALB → ECS Task → Drupal → RDS
```

1. **Internet**: User request to application URL
2. **Route 53**: DNS resolution (if custom domain)
3. **ALB**: Load balancing and health checks
4. **ECS Task**: Drupal application processing
5. **RDS**: Database queries and data retrieval

### 2. Response Flow

```
RDS → Drupal → ECS Task → ALB → Internet
```

1. **RDS**: Database response
2. **Drupal**: Application processing
3. **ECS Task**: Container response
4. **ALB**: Response routing
5. **Internet**: User receives response

### 3. Monitoring Flow

```
ECS/RDS/ALB → CloudWatch → Dashboard/Alarms
```

1. **Infrastructure**: Metrics and logs generation
2. **CloudWatch**: Data collection and processing
3. **Dashboard**: Real-time monitoring
4. **Alarms**: Automated notifications

## Security Architecture

### 1. Network Security

- **VPC Isolation**: Private subnets for sensitive resources
- **Security Groups**: Restrictive access controls
- **NACLs**: Additional network-level security
- **Internet Gateway**: Controlled public access

### 2. Application Security

- **SSL/TLS**: HTTPS encryption
- **IAM Roles**: Least privilege access
- **Secrets Management**: Database credentials
- **Container Security**: Image scanning and updates

### 3. Data Security

- **Encryption at Rest**: RDS storage encryption
- **Encryption in Transit**: TLS for all connections
- **Backup Encryption**: Automated backup security
- **Access Control**: Database user permissions

## Scalability Features

### 1. Horizontal Scaling

- **ECS Auto Scaling**: Based on CPU/memory metrics
- **ALB**: Distributes traffic across instances
- **Multi-AZ**: High availability across zones

### 2. Vertical Scaling

- **RDS**: Instance class upgrades
- **Storage**: Auto-scaling storage
- **Fargate**: CPU/memory adjustments

### 3. Performance Optimization

- **Connection Pooling**: Database connection management
- **Caching**: Application-level caching
- **CDN Ready**: CloudFront integration possible

## Cost Optimization

### 1. Resource Optimization

- **Fargate Spot**: Cost-effective compute
- **RDS Reserved Instances**: Predictable workloads
- **Storage Optimization**: GP2 with auto-scaling

### 2. Monitoring and Alerts

- **Cost Alerts**: Budget monitoring
- **Resource Utilization**: Performance monitoring
- **Auto Scaling**: Scale down during low usage

## Disaster Recovery

### 1. Backup Strategy

- **RDS Backups**: Automated daily backups
- **Snapshot Retention**: 7-day retention
- **Cross-Region**: Backup replication possible

### 2. Recovery Procedures

- **RDS Restore**: Point-in-time recovery
- **ECS Redeployment**: Container restart
- **ALB Failover**: Automatic failover

## Monitoring and Alerting

### 1. Key Metrics

- **ECS**: CPU, Memory, Task Count
- **RDS**: CPU, Connections, Storage
- **ALB**: Request Count, Response Time
- **Application**: Error Rate, Response Time

### 2. Alarms

- **High CPU**: >80% for 2 periods
- **High Memory**: >80% for 2 periods
- **Database Issues**: Connection failures
- **Application Errors**: Error rate thresholds

## Future Enhancements

### 1. Advanced Features

- **CDN**: CloudFront integration
- **WAF**: Web Application Firewall
- **Redis**: Caching layer
- **Elasticsearch**: Search functionality

### 2. Multi-Region

- **Global Distribution**: Route 53 with latency routing
- **Cross-Region Replication**: RDS read replicas
- **Disaster Recovery**: Active-passive setup

### 3. CI/CD Pipeline

- **GitHub Actions**: Automated deployment
- **CodePipeline**: AWS-native CI/CD
- **Blue-Green Deployment**: Zero-downtime updates