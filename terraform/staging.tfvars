# ============================================================================
# STAGING ENVIRONMENT CONFIGURATION - OPTION A (REALISTIC)
# ============================================================================
# This file defines settings for the staging environment
# Use with: terraform apply -var-file="staging.tfvars"
#
# CONFIGURATION: Realistic staging (mirrors production architecture)
# Purpose: Safe testing environment that MIRRORS production setup
# Cost: ~$18/month (~$8 EC2 + ~$15 RDS + $2 EBS if running 24/7)
#       ~$10/month if only run 8-10 hours/week for testing
#
# WHY THIS APPROACH:
# - Same database type (RDS PostgreSQL) catches DB issues before prod
# - Same monitoring setup ensures alerts work correctly
# - Same architecture reduces "works in staging, fails in prod" issues
# - Only difference: Smaller instance sizes and fewer instances
# ============================================================================

# ----------------------------------------------------------------------------
# Environment Settings
# ----------------------------------------------------------------------------
environment = "staging"
aws_region  = "eu-west-1" # Same region as production for simplicity

# ----------------------------------------------------------------------------
# EC2 Instance Configuration
# ----------------------------------------------------------------------------
# Using t3.micro (same as prod) for realistic testing
# Could use t3.nano to save costs if acceptable
instance_type = "t3.micro"

# SSH Key (reuse same key as production)
key_pair_name = "codedetect-key"
allowed_ssh_ip = "80.233.75.162/32"  #current IP (same as prod for now)

# ----------------------------------------------------------------------------
# Blue/Green Deployment Configuration
# ----------------------------------------------------------------------------
# Start with blue environment active
active_environment = "blue"

# ----------------------------------------------------------------------------
# S3 Configuration
# ----------------------------------------------------------------------------
# IMPORTANT: S3 bucket names must be globally unique!
# Must be different from production bucket
s3_bucket_name = "codedetect-staging-uploads-2025"

# ----------------------------------------------------------------------------
# Database Configuration
# ----------------------------------------------------------------------------
# Database name for staging
db_name = "codedetect_staging"

# RDS Configuration
# OPTION A (REALISTIC): Use RDS to mirror production architecture
# This costs ~$15/month but catches RDS-specific issues before production
# RECOMMENDED for serious staging environment
use_rds = true  # Changed to TRUE for realistic testing

# RDS Settings (active when use_rds = true):
db_username        = "codedetect_staging"
db_instance_class  = "db.t3.micro" # Smallest RDS instance (same as prod)
db_allocated_storage = 20          # Minimum storage

# NOTE: db_password should be passed via GitHub Secrets or terraform -var
# Do NOT hardcode passwords in this file!

# ----------------------------------------------------------------------------
# Docker Image Configuration
# ----------------------------------------------------------------------------
# Docker Hub repository
docker_image_repo = "nyeinthunaing/codedetect"

# Docker tag for staging
# Options:
# - "staging-latest" - always pull latest staging build
# - "staging-<commit-sha>" - specific version to test
# - "blue-<commit-sha>" - test production image before deploying
docker_tag = "staging-latest"

# ----------------------------------------------------------------------------
# Monitoring & Logging
# ----------------------------------------------------------------------------
# OPTION A (REALISTIC): Enable monitoring to match production
# This ensures alerts and dashboards work the same way in staging
# Cost: Included in EC2 pricing (detailed monitoring is free for t3 instances)
enable_monitoring = true  # Changed to TRUE to mirror production

# ----------------------------------------------------------------------------
# DNS Configuration
# ----------------------------------------------------------------------------
# Disable custom domain for staging
# Access via ALB DNS instead: http://codedetect-staging-alb-*.elb.amazonaws.com
enable_dns = false

# If you want staging subdomain:
# enable_dns = true
# domain_name = "staging.codedetect.com"

# ----------------------------------------------------------------------------
# SSL/TLS Configuration
# ----------------------------------------------------------------------------
# Disable SSL for staging to save time on certificate validation
# Use HTTP only: http://staging-alb-*.amazonaws.com
enable_ssl = false

# If you need HTTPS for testing:
# enable_ssl = true
# ssl_certificate_arn = "arn:aws:acm:eu-west-1:ACCOUNT:certificate/CERT_ID"

# ----------------------------------------------------------------------------
# Cost Optimization Settings
# ----------------------------------------------------------------------------
# These settings reduce staging costs while maintaining realistic testing

# Reduce instance count (1 instance per environment, no HA needed for staging)
# This is already the default, but explicitly set here for clarity

# Disable NAT Gateway (use public subnets only)
# If you need private subnets for testing:
# create_nat_gateway = false

# ----------------------------------------------------------------------------
# Notifications
# ----------------------------------------------------------------------------
# Email for CloudWatch alarms and SNS notifications
notification_email = "nyeinthunaing322@gmail.com"  # CHANGE THIS!
owner_email = "nyeinthunaing322@gmail.com"  # CHANGE THIS!

# ----------------------------------------------------------------------------
# Tagging Configuration
# ----------------------------------------------------------------------------
# Tags are automatically applied based on environment variable
# Additional custom tags can be added here if needed

# Example custom tags (uncomment if needed):
# custom_tags = {
#   CostCenter = "Engineering"
#   Owner      = "DevTeam"
#   Purpose    = "Testing"
# }

# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Deploy staging environment:
#   terraform workspace select staging
#   terraform plan -var-file="staging.tfvars"
#   terraform apply -var-file="staging.tfvars"
#
# Update staging with new Docker image:
#   # Edit docker_tag above to new version
#   terraform workspace select staging
#   terraform apply -var-file="staging.tfvars"
#
# Destroy staging to save costs:
#   terraform workspace select staging
#   terraform destroy -var-file="staging.tfvars"
#
# Get staging URL:
#   terraform workspace select staging
#   terraform output load_balancer_url
#
# ============================================================================
# IMPORTANT NOTES
# ============================================================================
#
# 1. S3 bucket name MUST be different from production
# 2. Always verify workspace before applying: terraform workspace show
# 3. Destroy staging when not in use to minimize costs
# 4. Use "staging-" prefix for Docker tags to avoid confusion
# 5. Don't use production credentials/secrets in staging
# 6. Staging data is NOT backed up - use fake/test data only
#
# ============================================================================
