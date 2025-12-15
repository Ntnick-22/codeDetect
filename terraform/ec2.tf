# ============================================================================
# EC2 CONFIGURATION
# ============================================================================
# Defines IAM roles, instance profiles, and user data script for EC2 instances
# Instances are launched via Auto Scaling Group (see loadbalancer.tf)
# ============================================================================

# ----------------------------------------------------------------------------
# SSH KEY PAIR
# ----------------------------------------------------------------------------
# References existing SSH key pair in AWS for instance access
data "aws_key_pair" "main" {
  key_name = var.key_pair_name
}

# ----------------------------------------------------------------------------
# USER DATA SCRIPT
# ----------------------------------------------------------------------------
# Runs automatically when EC2 instance first boots
# Installs Docker, clones repo, pulls Docker image, and starts application

locals {
  user_data = <<-EOF
    #!/bin/bash
    # CodeDetect EC2 Setup Script
    # Runs once on first boot to configure the instance

    # Update system packages
    yum update -y

    # Install Docker
    yum install -y docker

    # Start Docker service
    systemctl start docker
    systemctl enable docker

    # Add ec2-user to docker group (run docker without sudo)
    usermod -a -G docker ec2-user

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Install Git
    yum install -y git

    # Create app directory
    mkdir -p /home/ec2-user/app
    chown ec2-user:ec2-user /home/ec2-user/app

    # Log completion
    echo "CodeDetect setup complete!" > /home/ec2-user/setup-complete.txt

    # ========================================================================
    # AUTO-DEPLOY APPLICATION
    # ========================================================================
    echo "=== Starting automatic deployment ===" >> /var/log/codedetect-deploy.log
    cd /home/ec2-user/app

    # Clone repository to get docker-compose.yml and configuration
    echo "Cloning repository..." >> /var/log/codedetect-deploy.log
    su - ec2-user -c "cd /home/ec2-user/app && git clone https://github.com/Ntnick-22/codeDetect.git . 2>&1" >> /var/log/codedetect-deploy.log

    if [ ! -f /home/ec2-user/app/docker-compose.yml ]; then
      echo "ERROR: docker-compose.yml not found" >> /var/log/codedetect-deploy.log
      exit 1
    fi
    echo "Repository cloned successfully" >> /var/log/codedetect-deploy.log

    # Pull pre-built Docker image from Docker Hub
    echo "Pulling Docker image: ${var.docker_image_repo}:${var.docker_tag}" >> /var/log/codedetect-deploy.log
    su - ec2-user -c "docker pull ${var.docker_image_repo}:${var.docker_tag} 2>&1" >> /var/log/codedetect-deploy.log

    # Tag image for docker-compose compatibility
    echo "Tagging image as codedetect-app:latest" >> /var/log/codedetect-deploy.log
    su - ec2-user -c "docker tag ${var.docker_image_repo}:${var.docker_tag} codedetect-app:latest 2>&1" >> /var/log/codedetect-deploy.log

    # Verify image is available
    su - ec2-user -c "docker images | grep codedetect-app" >> /var/log/codedetect-deploy.log

    # Wait for Docker to be fully ready
    sleep 5

    # ========================================================================
    # FETCH SECRETS FROM PARAMETER STORE
    # ========================================================================
    echo "Fetching secrets from Parameter Store..." >> /var/log/codedetect-deploy.log

    # Fetch RDS database password
    DB_PASSWORD=$(aws ssm get-parameter \
      --name "codedetect-prod-db-password" \
      --with-decryption \
      --region ${var.aws_region} \
      --query 'Parameter.Value' \
      --output text 2>/dev/null || echo "")

    if [ -z "$DB_PASSWORD" ]; then
      echo "ERROR: Failed to fetch DB_PASSWORD from Parameter Store" >> /var/log/codedetect-deploy.log
      DB_PASSWORD="fallback_password"  # Fallback (should not be used in prod)
    else
      echo "Successfully fetched DB_PASSWORD" >> /var/log/codedetect-deploy.log
    fi

    # Fetch SNS topic ARN for feedback system
    SNS_TOPIC_ARN=$(aws ssm get-parameter \
      --name "codedetect-prod-sns-topic-arn" \
      --region ${var.aws_region} \
      --query 'Parameter.Value' \
      --output text 2>/dev/null || echo "")

    # ========================================================================
    # CREATE ENVIRONMENT FILE
    # ========================================================================
    # These environment variables are injected into the Docker container
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
SNS_TOPIC_ARN=$SNS_TOPIC_ARN

# Database Configuration (RDS PostgreSQL)
DATABASE_URL=postgresql://codedetect_user:$DB_PASSWORD@${aws_db_instance.main[0].address}:5432/codedetect_db
ENVFILE

    chown ec2-user:ec2-user /home/ec2-user/app/.env
    echo "Environment file created" >> /var/log/codedetect-deploy.log

   

    su - ec2-user -c "cd /home/ec2-user/app && docker-compose up -d 2>&1" >> /var/log/codedetect-deploy.log

    echo "=== Deployment complete at $(date) ===" >> /var/log/codedetect-deploy.log
    echo "Application deployed successfully!" > /home/ec2-user/deployment-complete.txt
  EOF
}

# ----------------------------------------------------------------------------
# IAM ROLE FOR EC2 INSTANCES
# ----------------------------------------------------------------------------
#


resource "aws_iam_role" "ec2" {
  name = "${local.name_prefix}-ec2-role"

  # Trust policy: Allows EC2 service to assume this role
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

# ----------------------------------------------------------------------------
# IAM POLICY - S3 ACCESS
# ----------------------------------------------------------------------------
# Allows EC2 instances to read/write uploaded Python files to S3

resource "aws_iam_role_policy" "ec2_s3_access" {
  name = "${local.name_prefix}-ec2-s3-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",      # Download files
          "s3:PutObject",      # Upload files
          "s3:DeleteObject",   # Delete files
          "s3:ListBucket"      # List bucket contents
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
# IAM POLICY - PARAMETER STORE ACCESS
# ----------------------------------------------------------------------------
# Allows EC2 instances to read secrets from AWS Systems Manager Parameter Store
# This includes database passwords, API keys, and other sensitive configuration

resource "aws_iam_role_policy" "ec2_ssm_access" {
  name = "${local.name_prefix}-ec2-ssm-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",         # Read single parameter
          "ssm:GetParameters",        # Read multiple parameters
          "ssm:GetParametersByPath"   # Read all parameters under a path
        ]
        # Restrict to only this project's parameters
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.app_name}/${var.environment}/*",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.app_name}-${var.environment}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters"  # List parameters (doesn't expose values)
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"  # Decrypt SecureString parameters
        ]
        # Use default AWS managed key for SSM
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/alias/aws/ssm"
      }
    ]
  })
}

# ----------------------------------------------------------------------------
# IAM INSTANCE PROFILE
# ----------------------------------------------------------------------------
# Wrapper that attaches the IAM role to EC2 instances
# EC2 instances reference this profile, not the role directly

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = local.common_tags
}

# ============================================================================
# NOTES
# ============================================================================
#
# ARCHITECTURE EVOLUTION:
# - Phase 1: Single EC2 instance with local SQLite database
# - Phase 2: EFS for shared database between instances (removed)
# - Phase 3: RDS PostgreSQL for managed database (current)
# - Phase 4: Auto Scaling Group for high availability
#
# WHY RDS INSTEAD OF EFS:
# - RDS is managed (automatic backups, updates, failover)
# - Better performance for database workloads
# - Simpler setup (no file locking issues)
# - Multi-AZ support for high availability (I used only one az for cost optimization for this project)
#
# WHY S3 INSTEAD OF EFS:
# - S3 is cheaper for file storage ($0.023/GB vs $0.30/GB)
# - Lifecycle policies for automatic cleanup
# - Better for temporary uploads (7-day retention)
#
# IAM ROLE VS HARDCODED CREDENTIALS:
# - IAM role is more secure (no credentials in code or config files)
# - Credentials rotate automatically
# - Can be easily audited and restricted
#
# ============================================================================
