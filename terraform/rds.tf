# ============================================================================
# RDS POSTGRESQL DATABASE
# ============================================================================
# Production-grade managed PostgreSQL database
# - Single-AZ for free tier eligibility
# - Can upgrade to Multi-AZ later for high availability
# - Shared by both EC2 instances via VPC networking
# ============================================================================

# ----------------------------------------------------------------------------
# PRIVATE SUBNETS FOR RDS
# ----------------------------------------------------------------------------
# RDS requires at least 2 private subnets in different availability zones
# Even for Single-AZ, the subnet group needs 2 subnets

# Private Subnet 1 (AZ-1)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24" # 256 IPs (10.0.3.0 - 10.0.3.255)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-subnet-1"
      Type = "Private"
    }
  )
}

# Private Subnet 2 (AZ-2)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24" # 256 IPs (10.0.4.0 - 10.0.4.255)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-subnet-2"
      Type = "Private"
    }
  )
}

# ----------------------------------------------------------------------------
# RDS SUBNET GROUP
# ----------------------------------------------------------------------------
# Groups the private subnets for RDS to use
# RDS will launch in one of these subnets

resource "aws_db_subnet_group" "main" {
  count = var.use_rds ? 1 : 0 # Only create if use_rds = true

  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-db-subnet-group"
    }
  )
}

# ----------------------------------------------------------------------------
# RDS SECURITY GROUP
# ----------------------------------------------------------------------------
# Firewall rules for RDS database

resource "aws_security_group" "rds" {
  count = var.use_rds ? 1 : 0 # Only create if use_rds = true

  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rds-sg"
    }
  )
}

# Allow PostgreSQL access from EC2 instances only
resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  count = var.use_rds ? 1 : 0 # Only create if use_rds = true

  security_group_id            = aws_security_group.rds[0].id
  description                  = "PostgreSQL access from EC2 instances"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id # Only from EC2 security group

  tags = {
    Name = "PostgreSQL from EC2"
  }
}

# Allow all outbound traffic from RDS (for updates, etc.)
resource "aws_vpc_security_group_egress_rule" "rds_egress" {
  count = var.use_rds ? 1 : 0 # Only create if use_rds = true

  security_group_id = aws_security_group.rds[0].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1" # All protocols
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "RDS Outbound"
  }
}

# ----------------------------------------------------------------------------
# RDS POSTGRESQL INSTANCE
# ----------------------------------------------------------------------------
# The actual database server

resource "aws_db_instance" "postgres" {
  count = var.use_rds ? 1 : 0 # Only create if use_rds = true

  # ============================================================
  # INSTANCE CONFIGURATION
  # ============================================================
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version # PostgreSQL 15.4

  # FREE TIER ELIGIBLE SETTINGS
  instance_class    = var.db_instance_class    # db.t3.micro (FREE for 12 months)
  allocated_storage = var.db_allocated_storage # 20 GB (FREE for 12 months)
  storage_type      = "gp2"                    # General Purpose SSD (gp2 for free tier, NOT gp3)
  storage_encrypted = true                     # Encrypt data at rest (security best practice)

  # SINGLE-AZ FOR FREE TIER
  multi_az = false # Set to true later for high availability (costs 2x)

  # ============================================================
  # DATABASE CREDENTIALS
  # ============================================================
  db_name  = var.db_name     # "codedetect"
  username = var.db_username # "codedetect_admin"
  password = var.db_password # From terraform.tfvars or Parameter Store

  # ============================================================
  # NETWORK CONFIGURATION
  # ============================================================
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  publicly_accessible    = false # NOT accessible from internet (security!)

  # ============================================================
  # BACKUP CONFIGURATION
  # ============================================================
  backup_retention_period = var.db_backup_retention_days # 7 days (FREE)
  backup_window           = "03:00-04:00"                # 3-4 AM UTC (low traffic time)
  maintenance_window      = "sun:04:00-sun:05:00"        # Sunday 4-5 AM UTC

  # Automated backups to S3 (FREE for up to 20GB)
  # Can restore to any point in time within retention period

  # ============================================================
  # PERFORMANCE & MONITORING
  # ============================================================
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"] # Send logs to CloudWatch
  monitoring_interval             = 60                        # Enhanced monitoring every 60 seconds
  monitoring_role_arn             = aws_iam_role.rds_monitoring[0].arn

  # Performance Insights (FREE for 7 days retention)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # FREE tier = 7 days

  # ============================================================
  # DELETION PROTECTION
  # ============================================================
  deletion_protection = false # Set to true in production!
  skip_final_snapshot = true  # Set to false in production!
  # final_snapshot_identifier = "${local.name_prefix}-postgres-final-snapshot"

  # ⚠️ For development/testing, we allow easy deletion
  # ⚠️ In production, enable deletion_protection and final snapshots!

  # ============================================================
  # TAGS
  # ============================================================
  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-postgres"
      Service  = "RDS"
      Database = "PostgreSQL"
    }
  )
}

# ----------------------------------------------------------------------------
# IAM ROLE FOR RDS ENHANCED MONITORING
# ----------------------------------------------------------------------------
# Allows RDS to send metrics to CloudWatch

resource "aws_iam_role" "rds_monitoring" {
  count = var.use_rds ? 1 : 0 # Only create if use_rds = true

  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach AWS managed policy for RDS monitoring
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.use_rds ? 1 : 0 # Only create if use_rds = true

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint for database connection"
  value       = var.use_rds ? aws_db_instance.postgres[0].endpoint : "RDS not enabled (using SQLite)"
}

output "rds_address" {
  description = "RDS PostgreSQL hostname (without port)"
  value       = var.use_rds ? aws_db_instance.postgres[0].address : "RDS not enabled"
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = var.use_rds ? aws_db_instance.postgres[0].port : 5432
}

output "database_name" {
  description = "RDS database name"
  value       = var.use_rds ? var.db_name : "codedetect"
}

output "database_username" {
  description = "RDS database username"
  value       = var.use_rds ? var.db_username : "codedetect"
}

# Note: database_url output removed due to Terraform limitation
# Sensitive variables (db_password) cannot be used in conditional expressions
# The connection string is constructed in EC2 user data instead

# ============================================================================
# COST ESTIMATE
# ============================================================================
# FREE TIER (First 12 months):
# - RDS db.t3.micro: 750 hours/month FREE
# - Storage 20GB: FREE
# - Backups 20GB: FREE
# Total: $0/month
#
# AFTER FREE TIER:
# - RDS db.t3.micro: ~$15/month (24/7)
# - Storage 20GB gp2: ~$2.30/month
# - Backups 20GB: ~$2/month
# Total: ~$19/month
#
# MULTI-AZ (Optional Upgrade):
# - Doubles instance cost: ~$30/month + storage
# Total: ~$35/month
# ============================================================================
