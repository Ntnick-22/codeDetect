# ============================================================================
# CODEDETECT - TERRAFORM VARIABLES
# ============================================================================
# This file defines all configurable parameters for the infrastructure
# Change these values to customize your deployment
# ============================================================================

# ----------------------------------------------------------------------------
# GENERAL CONFIGURATION
# ----------------------------------------------------------------------------

# AWS Region where resources will be created
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1" # Ireland - Your preferred region

  # eu-west-1 is good choice: stable, close to Europe, full service availability
}

# Environment name (dev, staging, prod)
variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"

  # Validation: Only allow specific values
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# Active environment for blue/green deployment
variable "active_environment" {
  description = "Active environment for blue/green deployment (blue or green)"
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_environment)
    error_message = "Active environment must be either 'blue' or 'green'"
  }
}

# Your email address (for tagging and notifications)
variable "owner_email" {
  description = "Email address of the project owner"
  type        = string
  default     = "your-email@example.com" # CHANGE THIS!
}

# ----------------------------------------------------------------------------
# NETWORK CONFIGURATION
# ----------------------------------------------------------------------------

# VPC CIDR block (IP range for your private network)
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  # This gives you 65,536 IP addresses
  # Format: 10.0.0.0 to 10.0.255.255
}

# Number of availability zones to use
variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2

  # Using 2 AZs provides high availability
  # Your app continues working if one data center fails
}

# ----------------------------------------------------------------------------
# EC2 INSTANCE CONFIGURATION
# ----------------------------------------------------------------------------

# EC2 instance type (size of your server)
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"

  # Options:
  # - t3.micro:  1 vCPU, 1 GB RAM   ($0.0104/hour) - Too small
  # - t3.small:  2 vCPU, 2 GB RAM   ($0.0208/hour) - Good for demo
  # - t3.medium: 2 vCPU, 4 GB RAM   ($0.0416/hour) - Better performance
  # - t3.large:  2 vCPU, 8 GB RAM   ($0.0832/hour) - Production ready
}

# EC2 key pair name for SSH access
variable "key_pair_name" {
  description = "Name of EC2 key pair for SSH access"
  type        = string
  default     = "codedetect-key"

  # You'll need to create this key pair manually in AWS Console first
  # Or we can create it with Terraform (see ec2.tf)
}

# Allow SSH from specific IP only (for security)
variable "allowed_ssh_ip" {
  description = "Your IP address allowed to SSH (CIDR format)"
  type        = string
  default     = "0.0.0.0/0" # WARNING: Allows from anywhere - CHANGE THIS!

  # Get your IP: Go to https://whatismyip.com
  # Then use format: YOUR_IP/32
  # Example: "203.0.113.45/32"
}

# ----------------------------------------------------------------------------
# RDS DATABASE CONFIGURATION
# ----------------------------------------------------------------------------

# Database instance class (size)

# Use RDS or SQLite
variable "use_rds" {
  description = "Use RDS or stick with SQLite in Docker"
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"

  # Options:
  # - db.t3.micro:  1 vCPU, 1 GB RAM   - Free tier eligible!
  # - db.t3.small:  2 vCPU, 2 GB RAM   - Better performance
  # - db.t3.medium: 2 vCPU, 4 GB RAM   - Production ready
}

# Database engine version
variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4" # Latest stable PostgreSQL version
}

# Database name
variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "codedetect"
}

# Database username
variable "db_username" {
  description = "Master username for database"
  type        = string
  default     = "codedetect_admin"

  # Don't use 'admin' or 'root' - too common
}

# Database password (IMPORTANT: Use secrets manager in production!)
variable "db_password" {
  description = "Master password for database"
  type        = string
  sensitive   = true # Hides value in Terraform output

  # For this project, you'll set this when running terraform apply
  # In production, use AWS Secrets Manager instead
}

# Database storage size in GB
variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20 # 20 GB is minimum for RDS
}

# Enable database backups
variable "db_backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7 # Keep backups for 7 days
}

# ----------------------------------------------------------------------------
# S3 BUCKET CONFIGURATION
# ----------------------------------------------------------------------------

# S3 bucket name (must be globally unique!)
variable "s3_bucket_name" {
  description = "Name for S3 bucket (must be globally unique)"
  type        = string
  default     = "codedetect-uploads" # CHANGE THIS - add random suffix

  # S3 bucket names must be unique across ALL of AWS
  # Add your name or random string: "codedetect-uploads-yourname-12345"
}

# Enable S3 versioning (keep old versions of files)
variable "s3_enable_versioning" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true

  # true = Can recover deleted/overwritten files
  # false = Files are permanently deleted/replaced
}

# ----------------------------------------------------------------------------
# DOMAIN CONFIGURATION
# ----------------------------------------------------------------------------

# Your domain name
variable "domain_name" {
  description = "nt-nick.link"
  type        = string
  default     = "example.com" # CHANGE THIS to your actual domain!

  # Example: "yourdomain.com"
}

# Subdomain for the app
variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "codedetect"

  # Full URL will be: codedetect.yourdomain.com
}

# ----------------------------------------------------------------------------
# APPLICATION CONFIGURATION
# ----------------------------------------------------------------------------

# Docker image repository (username/repo)
variable "docker_image_repo" {
  description = "Docker Hub repository (username/imagename)"
  type        = string
  default     = "nyeinthunaing/codedetect"

  # Docker Hub repository for pulling images
}

# Docker image tag (version)
variable "docker_tag" {
  description = "Docker image tag to deploy (e.g., v1.0, v1.1, latest)"
  type        = string
  default     = "v1.0"

  # This is the version of your application to deploy
  # Blue/Green deployments can use different tags
  # Example: Blue runs v1.0, Green runs v1.1
}

# Application port
variable "app_port" {
  description = "Port the application runs on"
  type        = number
  default     = 5000
}

# Enable HTTPS
variable "enable_https" {
  description = "Enable HTTPS with SSL certificate"
  type        = bool
  default     = true

  # true = Secure connection (recommended)
  # false = HTTP only (not secure)
}

# ----------------------------------------------------------------------------
# MONITORING & NOTIFICATIONS
# ----------------------------------------------------------------------------

# Email for SNS notifications
variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
  default     = "nyeinthunaing322@.com" # CHANGE THIS!
}

# Enable CloudWatch monitoring
variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true

  # true = More detailed metrics (costs extra)
  # false = Basic monitoring only (free)
}

# ============================================================================
# HOW TO USE THESE VARIABLES
# ============================================================================

# METHOD 1: Use default values (easiest)
# Just run: terraform apply
# It will use all the default values above

# METHOD 2: Override via command line
# terraform apply -var="instance_type=t3.medium" -var="environment=dev"

# METHOD 3: Create terraform.tfvars file (recommended)
# Create file: terraform.tfvars
# Add your values:
#   aws_region = "us-west-2"
#   owner_email = "you@email.com"
#   domain_name = "yourdomain.com"
#   db_password = "YourSecurePassword123!"

# METHOD 4: Use environment variables
# export TF_VAR_db_password="SecurePassword123"
# terraform apply

# ============================================================================