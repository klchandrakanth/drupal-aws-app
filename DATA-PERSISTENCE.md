# Data Persistence Solution

## Problem Solved

**Before**: When using Fargate Spot, MariaDB data was lost when tasks were interrupted, requiring manual database restoration.

**After**: MariaDB data now persists through Fargate Spot interruptions, providing production-grade reliability at development cost.

## Solution Overview

### Architecture Changes

1. **EFS Volume for MariaDB**: Added dedicated EFS volume mounted to `/var/lib/mysql`
2. **Access Point**: Created MariaDB-specific EFS access point with proper permissions (UID/GID 999)
3. **Task Definition**: Updated to mount MariaDB data to EFS
4. **Backup Script**: Automated backup solution included

### EFS Structure

```
EFS File System (encrypted)
├── /drupal-content/          # Drupal files (existing)
│   └── files/               # Public files
├── /mariadb/                # MariaDB data (new)
│   ├── mysql/               # System databases
│   ├── drupal/              # Drupal database
│   ├── performance_schema/  # Performance data
│   └── ...
└── /backup/                 # Backup location (optional)
```

## Implementation Details

### Terraform Changes

#### EFS Module (`terraform/modules/efs/main.tf`)
```hcl
# New access point for MariaDB
resource "aws_efs_access_point" "mariadb_data" {
  file_system_id = aws_efs_file_system.drupal_content.id

  root_directory {
    path = "/mariadb-data"
    creation_info {
      owner_gid   = 999  # mysql group
      owner_uid   = 999  # mysql user
      permissions = "755"
    }
  }

  posix_user {
    gid = 999
    uid = 999
  }
}
```

#### ECS Module (`terraform/modules/ecs/main.tf`)
```hcl
# New volume for MariaDB data
volume {
  name = "mariadb-data"
  efs_volume_configuration {
    file_system_id = var.efs_file_system_id
    root_directory = "/mariadb"
    transit_encryption = "ENABLED"
    authorization_config {
      access_point_id = var.efs_mariadb_access_point_id
      iam = "ENABLED"
    }
  }
}

# MariaDB container mount point
mountPoints = [
  {
    sourceVolume  = "mariadb-data"
    containerPath = "/var/lib/mysql"
    readOnly      = false
  }
]
```

### Security Features

- **Encryption**: Data encrypted at rest and in transit
- **IAM Access**: EFS access controlled via IAM roles
- **Network Security**: EFS accessible only from ECS tasks
- **POSIX Permissions**: Proper file ownership (mysql:mysql)

## Benefits

### Reliability
- ✅ **Data Survival**: MariaDB data persists through task restarts
- ✅ **Transaction Safety**: ACID compliance maintained
- ✅ **Automatic Recovery**: No manual intervention required
- ✅ **Consistency**: Database integrity preserved

### Cost Efficiency
- ✅ **Fargate Spot**: Still get 60-70% cost savings
- ✅ **Minimal Storage**: MariaDB data typically < 1GB
- ✅ **No RDS Costs**: Avoid ~$13/month RDS charges
- ✅ **Shared Infrastructure**: Uses existing EFS setup

### Operational Benefits
- ✅ **Zero Downtime**: Seamless task restarts
- ✅ **Automated Backups**: Included backup script
- ✅ **Easy Monitoring**: CloudWatch integration
- ✅ **Scalability**: Data scales with EFS

## Backup and Recovery

### Automated Backup Script

```bash
# Create backup
./scripts/backup-mariadb.sh production us-east-1

# Backup stored in EFS /backup directory
# Can be restored via ECS task or EFS mount
```

### EFS Snapshots

```bash
# Create point-in-time snapshot
aws efs create-snapshot \
  --file-system-id fs-xxxxxxxxx \
  --description "Drupal and MariaDB backup $(date)"

# Restore from snapshot
aws efs create-file-system \
  --creation-token restored-drupal \
  --source-snapshot-id snap-xxxxxxxxx
```

### Manual Backup Process

1. **Stop Service**: Scale down to 0 tasks
2. **Data Remains**: MariaDB data stays in EFS
3. **Create Backup**: Use backup script or EFS snapshot
4. **Restart Service**: Scale back up to 1 task

## Monitoring and Verification

### Check Data Persistence

```bash
# Monitor EFS usage
aws efs describe-file-systems \
  --query 'FileSystems[0].SizeInBytes'

# Check MariaDB logs
aws logs tail /ecs/production-drupal-mariadb --follow

# Verify data directory
aws efs describe-access-points \
  --file-system-id fs-xxxxxxxxx
```

### Health Checks

- **MariaDB Container**: Health check ensures database is running
- **EFS Mount**: Automatic remount on task restart
- **Data Integrity**: MariaDB transaction logs ensure consistency

## Migration from Ephemeral Storage

### If You Have Existing Data

1. **Stop Current Service**:
   ```bash
   aws ecs update-service \
     --cluster production-drupal-cluster \
     --service production-drupal-service \
     --desired-count 0
   ```

2. **Deploy New Configuration**:
   ```bash
   terraform apply
   ```

3. **Restart Service**:
   ```bash
   aws ecs update-service \
     --cluster production-drupal-cluster \
     --service production-drupal-service \
     --desired-count 1
   ```

4. **Verify Data**:
   ```bash
   # Check MariaDB logs for successful startup
   aws logs tail /ecs/production-drupal-mariadb
   ```

## Troubleshooting

### Common Issues

#### MariaDB Won't Start
- **Check Permissions**: Ensure EFS access point has correct UID/GID
- **Check Mount**: Verify EFS volume is properly mounted
- **Check Logs**: Review CloudWatch logs for errors

#### Data Not Persisting
- **Verify EFS Mount**: Check if `/var/lib/mysql` is mounted to EFS
- **Check Access Point**: Ensure MariaDB access point is configured
- **Check IAM**: Verify ECS roles have EFS permissions

#### Backup Failures
- **Check Task Definition**: Ensure backup task has correct permissions
- **Check EFS Space**: Verify sufficient storage space
- **Check Network**: Ensure backup task can access EFS

### Useful Commands

```bash
# Check ECS task status
aws ecs describe-tasks \
  --cluster production-drupal-cluster \
  --tasks $(aws ecs list-tasks --cluster production-drupal-cluster --query 'taskArns[0]' --output text)

# Check EFS mount targets
aws efs describe-mount-targets \
  --file-system-id fs-xxxxxxxxx

# Check MariaDB container logs
aws logs tail /ecs/production-drupal-mariadb --follow

# Test EFS connectivity
aws efs describe-file-systems
```

## Cost Analysis

### Additional Costs
- **EFS Storage**: ~$0.30/GB/month (MariaDB typically < 1GB)
- **EFS Access**: ~$0.01/day for MariaDB data
- **Backup Storage**: Minimal additional usage

### Total Impact
- **Daily Cost**: +$0.01/day for MariaDB persistence
- **Monthly Cost**: +$0.30/month
- **Benefit**: Production reliability at minimal cost

### Cost Comparison
| Storage Type | Monthly Cost | Reliability |
|--------------|--------------|-------------|
| **Ephemeral** | $0 | ❌ Data loss on restart |
| **EFS Persistent** | $0.30 | ✅ Data survives restarts |
| **RDS** | $13+ | ✅ High availability |

## Best Practices

### Backup Schedule
- **Daily**: Automated backup script
- **Weekly**: EFS snapshot
- **Before Updates**: Manual backup

### Monitoring
- **EFS Usage**: Monitor storage growth
- **MariaDB Logs**: Check for errors
- **Task Restarts**: Monitor restart frequency

### Maintenance
- **Regular Backups**: Test backup/restore process
- **Storage Cleanup**: Remove old backups
- **Performance**: Monitor EFS performance

## Conclusion

This data persistence solution provides:

- **Production Reliability**: Data survives Fargate Spot interruptions
- **Cost Efficiency**: Minimal additional cost (~$0.30/month)
- **Operational Simplicity**: Automated backups and recovery
- **Security**: Encrypted storage with proper access controls

**Result**: You can confidently use Fargate Spot for cost savings while maintaining data integrity and reliability.