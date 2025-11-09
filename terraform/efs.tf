# ============================================================================
# ELASTIC FILE SYSTEM (EFS) - SHARED STORAGE
# ============================================================================
# This file sets up EFS for shared SQLite database across multiple instances
# - Solves multi-instance data consistency problem
# - Both instances read/write to same database file
# - Data persists even if instances are terminated
# - Cost: ~$0.30/GB/month (your 8KB DB = practically free!)
# ============================================================================

# ----------------------------------------------------------------------------
# EFS FILE SYSTEM
# ----------------------------------------------------------------------------
# Creates the shared network drive

resource "aws_efs_file_system" "main" {
  # Enable encryption at rest for security
  encrypted = true

  # Performance mode
  # - generalPurpose: Good for most use cases (what we use)
  # - maxIO: For thousands of instances (overkill for us)
  performance_mode = "generalPurpose"

  # Throughput mode
  # - bursting: Scales with storage size (what we use, cheapest)
  # - provisioned: Fixed throughput (costs more, not needed)
  throughput_mode = "bursting"

  # Lifecycle policy: Move old data to cheaper "Infrequent Access" storage
  # After 30 days without access, move to IA storage ($0.025/GB vs $0.30/GB)
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Automatic backups (recommended)
  # Creates daily backups, retains for 35 days
  # Cost: $0.05/GB/month for backups (your 8KB = $0.0004/month)
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-efs"
    }
  )
}

# ----------------------------------------------------------------------------
# BACKUP POLICY (Optional but Recommended)
# ----------------------------------------------------------------------------
# Enables automatic daily backups via AWS Backup

resource "aws_efs_backup_policy" "main" {
  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"  # Set to "DISABLED" if you want to skip backups
  }
}

# ----------------------------------------------------------------------------
# SECURITY GROUP FOR EFS
# ----------------------------------------------------------------------------
# Firewall rules for the EFS file system

resource "aws_security_group" "efs" {
  name        = "${local.name_prefix}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-efs-sg"
    }
  )
}

# Allow NFS traffic from EC2 instances
resource "aws_vpc_security_group_ingress_rule" "efs_from_ec2" {
  security_group_id = aws_security_group.efs.id
  description       = "Allow NFS from EC2 instances"

  # Allow traffic from EC2 security group
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = 2049  # NFS port
  to_port                      = 2049
  ip_protocol                  = "tcp"

  tags = {
    Name = "${local.name_prefix}-efs-nfs-ingress"
  }
}

# Allow all outbound traffic (EFS needs to respond)
resource "aws_vpc_security_group_egress_rule" "efs_all" {
  security_group_id = aws_security_group.efs.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${local.name_prefix}-efs-egress"
  }
}

# ----------------------------------------------------------------------------
# EFS MOUNT TARGETS
# ----------------------------------------------------------------------------
# Creates connection points in each availability zone
# Your instances connect to the nearest mount target

# Mount target in Availability Zone 1 (where Instance 1 might be)
resource "aws_efs_mount_target" "az1" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.public_1.id
  security_groups = [aws_security_group.efs.id]
}

# Mount target in Availability Zone 2 (where Instance 2 might be)
resource "aws_efs_mount_target" "az2" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.public_2.id
  security_groups = [aws_security_group.efs.id]
}

# ----------------------------------------------------------------------------
# ACCESS POINT (Optional - for better security)
# ----------------------------------------------------------------------------
# Creates a specific entry point with permissions
# Ensures Docker container writes with correct user/group

resource "aws_efs_access_point" "database" {
  file_system_id = aws_efs_file_system.main.id

  # Root directory for this access point
  root_directory {
    path = "/database"

    creation_info {
      owner_gid   = 1000  # ec2-user group ID
      owner_uid   = 1000  # ec2-user user ID
      permissions = "755" # rwxr-xr-x
    }
  }

  # POSIX user that containers will use
  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-database-access-point"
    }
  )
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.main.id
}

output "efs_dns_name" {
  description = "DNS name for mounting EFS"
  value       = aws_efs_file_system.main.dns_name
}

output "efs_mount_command" {
  description = "Command to mount EFS on EC2"
  value       = "sudo mount -t efs -o tls ${aws_efs_file_system.main.id}:/ /mnt/efs"
}

# ============================================================================
# EFS EXPLANATION
# ============================================================================

# WHAT IS EFS?
# - Elastic File System = Shared network storage
# - Like a USB drive that multiple computers can access simultaneously
# - Fully managed by AWS (no servers to maintain)
# - Automatically scales (grows/shrinks with your data)

# WHY USE EFS FOR SQLITE?
# - You have 2+ EC2 instances (Auto Scaling Group)
# - Each instance needs to access the SAME database
# - SQLite is file-based (needs shared filesystem)
# - EFS provides that shared filesystem

# HOW IT WORKS:
# 1. EFS creates shared storage in AWS
# 2. Mount targets provide connection points in each AZ
# 3. EC2 instances mount EFS to /mnt/efs
# 4. Docker container stores database on /mnt/efs/database
# 5. Both instances read/write to same SQLite file

# DATA FLOW:
# User Request → Load Balancer → Instance 1 or 2
#   → Docker Container → SQLite on /mnt/efs/database
#   → EFS (shared between all instances)

# PERFORMANCE:
# - Bursting mode: 100 MB/s per TB of storage
# - Your 8KB database: More than enough performance
# - Latency: 1-3ms (acceptable for SQLite)
# - Not as fast as local disk, but worth it for data sharing

# COST BREAKDOWN:
# Standard Storage: $0.30/GB/month
# - Your 8KB database = $0.000024/month (FREE essentially)
# - Data transfer: FREE within same AZ
# - Backup: $0.05/GB/month = $0.0004/month
#
# Total estimated cost: ~$0.01-0.30/month
# (Compared to RDS: $15-30/month - HUGE SAVINGS!)

# AVAILABILITY:
# - Stored across multiple AZs automatically
# - If one AZ fails, data still accessible
# - 99.99% availability SLA

# BACKUP:
# - Automatic daily backups (enabled above)
# - 35 day retention
# - Can restore to any point in time
# - Cost: Minimal for small database

# ALTERNATIVES CONSIDERED:
# 1. RDS PostgreSQL: $15-30/month (EXPENSIVE, overkill)
# 2. Local disk: $0 but data not shared (your current problem)
# 3. S3: Can't use with SQLite (not a filesystem)
# 4. EFS: ~$0.30/month, perfect for your use case ✓

# LIMITATIONS TO KNOW:
# - SQLite on network storage is slower than local
# - Not recommended for >100 concurrent writes
# - For your use case (small .py files): PERFECT!
# - If you grow huge, consider PostgreSQL on RDS later

# SECURITY:
# - Encrypted at rest (AES-256)
# - Encrypted in transit (TLS)
# - IAM and security group controls
# - Only your EC2 instances can access

# MONITORING:
# - CloudWatch metrics automatic
# - Monitor: Storage size, throughput, connections
# - Set alerts if usage spikes

# ============================================================================
