# Use existing key pair (already created in AWS)
data "aws_key_pair" "main" {
  key_name = var.key_pair_name

  # This references the existing key pair in AWS
  # No need to upload public key file
}

# ----------------------------------------------------------------------------
# ELASTIC IP - REMOVED
# ----------------------------------------------------------------------------
# EIP was used for single EC2 instance setup
# Now using Application Load Balancer (ALB) which has its own DNS
# ALB DNS: codedetect-prod-alb-*.eu-west-1.elb.amazonaws.com
# Domain points to ALB via Route53 ALIAS record (see route53.tf)
# No static IP needed for HA setup with load balancer

# ----------------------------------------------------------------------------
# EC2 USER DATA SCRIPT
# ----------------------------------------------------------------------------
# This script runs automatically when EC2 instance first starts
# It installs Docker and prepares the server

locals {
  user_data = <<-EOF
    #!/bin/bash
    # CodeDetect EC2 Setup Script
    # This runs once when instance first boots

    # Update system packages
    yum update -y

    # Install Docker
    yum install -y docker

    # Start Docker service
    systemctl start docker
    systemctl enable docker

    # Add ec2-user to docker group (so we can run docker without sudo)
    usermod -a -G docker ec2-user

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Install Git (to clone your repo)
    yum install -y git

    # ========================================================================
    # EFS SETUP - Mount shared filesystem for database
    # ========================================================================
    # Install EFS utilities (needed to mount EFS)
    yum install -y amazon-efs-utils

    # Create mount point directory
    mkdir -p /mnt/efs

    # Mount EFS using the EFS ID
    # This mounts the shared drive where database will be stored
    echo "${aws_efs_file_system.main.id}:/ /mnt/efs efs _netdev,noresvport,tls 0 0" >> /etc/fstab

    # Mount all filesystems from fstab
    mount -a -t efs

    # Wait for EFS to be ready
    sleep 5

    # Create PostgreSQL directory on EFS (shared between all instances)
    mkdir -p /mnt/efs/postgres

    # Create uploads directory on EFS (shared file uploads)
    mkdir -p /mnt/efs/uploads

    # Set ownership to ec2-user so Docker can write to it
    chown -R ec2-user:ec2-user /mnt/efs/postgres
    chown -R ec2-user:ec2-user /mnt/efs/uploads
    chmod -R 755 /mnt/efs/postgres
    chmod -R 755 /mnt/efs/uploads

    echo "EFS mounted successfully at /mnt/efs" >> /var/log/codedetect-deploy.log
    # ========================================================================

    # ========================================================================
    # OLD NGINX INSTALLATION REMOVED
    # ========================================================================
    # We now use Nginx as a Docker container (in docker-compose.yml)
    # This provides:
    # - Version control (Nginx config in Git)
    # - Easier updates (just restart container)
    # - Consistent environments (dev/prod identical)
    # - Industry standard (containerized reverse proxy)
    #
    # The Nginx container (nginx:alpine) routes traffic:
    # - /grafana/* → Grafana container (port 3000)
    # - /*         → CodeDetect app (port 5000)
    # ========================================================================

    # Create app directory
    mkdir -p /home/ec2-user/app
    chown ec2-user:ec2-user /home/ec2-user/app

    # Log completion
    echo "CodeDetect setup complete!" > /home/ec2-user/setup-complete.txt

    # Auto-deploy application
    echo "=== Starting automatic deployment ===" >> /var/log/codedetect-deploy.log
    cd /home/ec2-user/app

    # Clone repository to get docker-compose.yml and configuration files
    echo "Cloning repository for docker-compose.yml" >> /var/log/codedetect-deploy.log
    su - ec2-user -c "cd /home/ec2-user/app && git clone https://github.com/Ntnick-22/codeDetect.git . 2>&1" >> /var/log/codedetect-deploy.log

    if [ ! -f /home/ec2-user/app/docker-compose.yml ]; then
      echo "ERROR: docker-compose.yml not found after git clone" >> /var/log/codedetect-deploy.log
      exit 1
    fi
    echo "Repository cloned successfully" >> /var/log/codedetect-deploy.log

    # Pull pre-built Docker image from Docker Hub (faster than building)
    echo "Pulling pre-built Docker image: ${var.docker_image_repo}:${var.docker_tag}" >> /var/log/codedetect-deploy.log
    su - ec2-user -c "docker pull ${var.docker_image_repo}:${var.docker_tag} 2>&1" >> /var/log/codedetect-deploy.log

    # Tag the image as codedetect-app:latest for docker-compose compatibility
    echo "Tagging image as codedetect-app:latest" >> /var/log/codedetect-deploy.log
    su - ec2-user -c "docker tag ${var.docker_image_repo}:${var.docker_tag} codedetect-app:latest 2>&1" >> /var/log/codedetect-deploy.log

    # Verify image is available
    echo "Verifying Docker image availability" >> /var/log/codedetect-deploy.log
    su - ec2-user -c "docker images | grep codedetect-app" >> /var/log/codedetect-deploy.log

    # Wait for Docker to be fully ready
    sleep 5

    # ========================================================================
    # AUTOMATIC DATA MIGRATION TO EFS (First Time Setup Only)
    # ========================================================================
    echo "=== Checking for existing data to migrate to EFS ===" >> /var/log/codedetect-deploy.log

    # Check if database already exists on EFS
    if [ ! -f /mnt/efs/database/codedetect.db ]; then
      echo "First time EFS setup detected - checking for existing data" >> /var/log/codedetect-deploy.log

      # Start temporary container with old volume to extract data
      # This runs BEFORE the new docker-compose to capture old data
      if docker volume ls | grep -q codedetect-data; then
        echo "Found existing codedetect-data volume - migrating to EFS" >> /var/log/codedetect-deploy.log

        # Use Alpine container to copy from old volume to EFS
        docker run --rm \
          -v codedetect-data:/old-data:ro \
          -v /mnt/efs/database:/new-data \
          alpine sh -c 'if [ -f /old-data/codedetect.db ]; then cp /old-data/codedetect.db /new-data/; echo "Database copied"; else echo "No database file found"; fi' \
          >> /var/log/codedetect-deploy.log 2>&1

        echo "=== Database migration completed ===" >> /var/log/codedetect-deploy.log
      else
        echo "No existing data volume found - starting with fresh database" >> /var/log/codedetect-deploy.log
      fi

      # Migrate uploads if they exist
      if docker volume ls | grep -q codedetect-uploads; then
        echo "Found existing codedetect-uploads volume - migrating to EFS" >> /var/log/codedetect-deploy.log

        docker run --rm \
          -v codedetect-uploads:/old-uploads:ro \
          -v /mnt/efs/uploads:/new-uploads \
          alpine sh -c 'cp -r /old-uploads/* /new-uploads/ 2>/dev/null || echo "No uploads to migrate"' \
          >> /var/log/codedetect-deploy.log 2>&1

        echo "=== Uploads migration completed ===" >> /var/log/codedetect-deploy.log
      fi
    else
      echo "Database already exists on EFS - skipping migration" >> /var/log/codedetect-deploy.log
    fi
    # ========================================================================

    # ========================================================================
    # SET DEPLOYMENT INFO ENVIRONMENT VARIABLES
    # ========================================================================
    # Fetch secrets from AWS Parameter Store
    # ========================================================================
    echo "Fetching secrets from Parameter Store..." >> /var/log/codedetect-deploy.log

    # Fetch database password
    DB_PASSWORD=$(aws ssm get-parameter \
      --name "codedetect-prod-db-password" \
      --with-decryption \
      --region ${var.aws_region} \
      --query 'Parameter.Value' \
      --output text 2>/dev/null || echo "")

    if [ -z "$DB_PASSWORD" ]; then
      echo "ERROR: Failed to fetch DB_PASSWORD from Parameter Store" >> /var/log/codedetect-deploy.log
      DB_PASSWORD="codedetect_secure_pass_2025"  # Fallback (for dev only)
    else
      echo "Successfully fetched DB_PASSWORD" >> /var/log/codedetect-deploy.log
    fi

    # ========================================================================
    # Fetch RDS endpoint (if RDS is enabled)
    # ========================================================================
    %{if var.use_rds}
    echo "Fetching RDS endpoint from Terraform outputs..." >> /var/log/codedetect-deploy.log
    RDS_ENDPOINT="${aws_db_instance.postgres[0].endpoint}"
    RDS_ADDRESS="${aws_db_instance.postgres[0].address}"

    if [ -z "$RDS_ENDPOINT" ]; then
      echo "ERROR: RDS endpoint not found!" >> /var/log/codedetect-deploy.log
      exit 1
    fi

    echo "RDS endpoint: $RDS_ENDPOINT" >> /var/log/codedetect-deploy.log
    %{else}
    echo "RDS not enabled - using SQLite" >> /var/log/codedetect-deploy.log
    RDS_ENDPOINT=""
    RDS_ADDRESS=""
    %{endif}
    # ========================================================================

    # ========================================================================
    # Create environment file with deployment metadata
    # These will be injected into Docker container for the /api/info endpoint
    cat > /home/ec2-user/app/.env <<ENVFILE
# Deployment Information
DOCKER_TAG=${var.docker_tag}
DEPLOYMENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(echo ${var.docker_tag} | grep -o '[a-f0-9]\{7\}' | head -1 || echo "unknown")
DEPLOYED_BY=github-actions
ACTIVE_ENVIRONMENT=${var.active_environment}
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

# Application Configuration
FLASK_ENV=prod
S3_BUCKET_NAME=${var.s3_bucket_name}
AWS_REGION=${var.aws_region}

# Database Configuration
%{if var.use_rds}
# AWS RDS PostgreSQL (production setup)
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_ADDRESS=$RDS_ADDRESS
DB_NAME=${var.db_name}
DB_USERNAME=${var.db_username}
DB_PASSWORD=$DB_PASSWORD
%{else}
# SQLite (local development only)
# RDS variables not set - docker-compose will use SQLite
%{endif}
ENVFILE

    chown ec2-user:ec2-user /home/ec2-user/app/.env
    echo "Environment variables configured" >> /var/log/codedetect-deploy.log
    # ========================================================================

    # ========================================================================
    # RDS SETUP - NO LOCK NEEDED
    # ========================================================================
    %{if var.use_rds}
    # Using AWS RDS PostgreSQL
    # - Both EC2 instances connect to same RDS database
    # - No lock file needed (RDS handles concurrent connections)
    # - No local PostgreSQL container running
    echo "Using AWS RDS PostgreSQL - both instances will connect to same database" >> /var/log/codedetect-deploy.log
    %{else}
    # Using SQLite on EFS (not recommended for production)
    echo "Using SQLite on EFS" >> /var/log/codedetect-deploy.log
    %{endif}
    # ========================================================================

    # Now start application
    su - ec2-user -c "cd /home/ec2-user/app && docker-compose up -d 2>&1" >> /var/log/codedetect-deploy.log

    echo "=== Deployment complete at $(date) ===" >> /var/log/codedetect-deploy.log
    echo "Application auto-deployed!" > /home/ec2-user/deployment-complete.txt
  EOF
}

# ----------------------------------------------------------------------------
# EC2 INSTANCE - REPLACED BY AUTO SCALING GROUP
# ----------------------------------------------------------------------------
# COMMENTED OUT: Now using Auto Scaling Group with Launch Template instead
# This provides high availability with automatic failover
# See loadbalancer.tf for the new setup

# resource "aws_instance" "main" {
#   # AMI (machine image) - using Amazon Linux 2
#   ami = data.aws_ami.amazon_linux_2.id
#
#   # Instance type (size)
#   instance_type = var.instance_type # t3.micro from variables
#
#   # SSH key for access
#   key_name = aws_key_pair.main.key_name
#
#   # Which subnet to launch in (public subnet 1)
#   subnet_id = aws_subnet.public_1.id
#
#   # Security group (firewall rules)
#   vpc_security_group_ids = [aws_security_group.ec2.id]
#
#   # User data script (runs on first boot)
#   user_data = local.user_data
#
#   # Root volume (main hard drive)
#   root_block_device {
#     volume_type = "gp3" # General Purpose SSD v3 (faster, cheaper)
#     volume_size = 20    # 20 GB (enough for Docker + app)
#     encrypted   = true  # Encrypt the drive for security
#
#     tags = {
#       Name = "${local.name_prefix}-root-volume"
#     }
#   }
#
#   # Enable detailed monitoring (optional, costs extra)
#   monitoring = var.enable_monitoring
#
#   # IAM role for accessing S3 (we'll create this next)
#   iam_instance_profile = aws_iam_instance_profile.ec2.name
#
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.name_prefix}-ec2"
#     }
#   )
#
#   # Ensure VPC and security group exist first
#   depends_on = [
#     aws_security_group.ec2,
#     aws_internet_gateway.main
#   ]
# }

# ----------------------------------------------------------------------------
# IAM ROLE FOR EC2
# ----------------------------------------------------------------------------
# Allows EC2 instance to access AWS services (like S3) without hardcoded keys

# IAM Role
resource "aws_iam_role" "ec2" {
  name = "${local.name_prefix}-ec2-role"

  # Trust policy: allows EC2 service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach policy allowing S3 access
resource "aws_iam_role_policy" "ec2_s3_access" {
  name = "${local.name_prefix}-ec2-s3-policy"
  role = aws_iam_role.ec2.id

  # Policy: Allow read/write to our S3 bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.uploads.arn,
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      }
    ]
  })
}

# ----------------------------------------------------------------------------
# IAM POLICY - SSM Parameter Store Access
# ----------------------------------------------------------------------------

# WHAT: IAM policy allowing EC2 to read parameters from Parameter Store
# WHY: So application can fetch secrets (API keys, passwords, config)
# without hardcoding them in code

# SECURITY NOTE:
# - Only allows GetParameter (read-only)
# - Only for our specific project parameters
# - Cannot create, update, or delete parameters
# - Cannot access other applications' parameters

resource "aws_iam_role_policy" "ec2_ssm_access" {
  name = "${local.name_prefix}-ec2-ssm-policy"
  role = aws_iam_role.ec2.id

  # Policy: Allow reading parameters from SSM Parameter Store
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",       # Read a single parameter
          "ssm:GetParameters",      # Read multiple parameters at once
          "ssm:GetParametersByPath" # Read all parameters under a path
        ]
        # Restrict to only our project's parameters
        # Supports both hierarchical (/codedetect/prod/*) and flat (codedetect-prod-*) naming
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.app_name}/${var.environment}/*",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.app_name}-${var.environment}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters" # List parameters (doesn't expose values)
        ]
        Resource = "*" # This action doesn't support resource-level permissions
      },
      {
        # Allow decryption of SecureString parameters
        # SecureString parameters are encrypted with KMS
        Effect = "Allow"
        Action = [
          "kms:Decrypt" # Decrypt SecureString values
        ]
        # Default AWS managed key for SSM
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/alias/aws/ssm"
      }
    ]
  })
}

# Instance profile (wrapper for the role)
resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = local.common_tags
}

# ============================================================================
# EC2 EXPLANATION
# ============================================================================

# WHAT IS EC2?
# - Elastic Compute Cloud
# - Virtual server in the cloud
# - Like renting a computer in AWS data center

# AMI (Amazon Machine Image):
# - Template for your EC2 instance
# - Includes OS (operating system) and pre-installed software
# - We use Amazon Linux 2 (optimized for AWS, free, secure)

# INSTANCE TYPES:
# - t3.micro = 2 vCPU, 1 GB RAM (what we're using)
# - t3 family = burstable (can use extra CPU when needed)
# - Good for apps with variable load

# USER DATA:
# - Script that runs ONCE when instance first starts
# - We use it to install Docker automatically
# - Saves manual setup time

# ELASTIC IP:
# - Static public IP address
# - Doesn't change when you stop/start instance
# - Needed so your domain always points to same IP
# - Free as long as it's attached to running instance

# IAM ROLE:
# - Allows EC2 to access other AWS services
# - Better than hardcoding AWS keys in your code
# - We use it so EC2 can write files to S3

# ROOT VOLUME:
# - The hard drive for your EC2 instance
# - gp3 = fast SSD storage
# - 20 GB is enough for OS + Docker + your app

# MONITORING:
# - Basic = Free, 5-minute intervals
# - Detailed = Costs extra, 1-minute intervals
# - We use basic (var.enable_monitoring = false)

# ============================================================================

# ----------------------------------------------------------------------------
# HOW TO ACCESS YOUR EC2 INSTANCE
# ----------------------------------------------------------------------------

# After Terraform creates it, SSH in with:
# ssh -i codedetect-key ec2-user@YOUR_ELASTIC_IP

# Then deploy your app:
# cd /home/ec2-user/app
# git clone https://github.com/yourusername/codedetect.git .
# docker-compose up -d

# ============================================================================