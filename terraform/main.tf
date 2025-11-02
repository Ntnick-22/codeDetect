# ============================================================================
# CODEDETECT - MAIN TERRAFORM CONFIGURATION
# ============================================================================
# This file defines the core AWS infrastructure for CodeDetect application
# Author: [Your Name]
# Project: CodeDetect - Automated Code Analysis Tool
# ============================================================================

# ----------------------------------------------------------------------------
# TERRAFORM CONFIGURATION
# ----------------------------------------------------------------------------
# Specifies which version of Terraform and which providers to use
terraform {
  # Require Terraform version 1.0 or higher
  required_version = ">= 1.0"

  # Define which cloud providers we'll use
  required_providers {
    # AWS provider for Amazon Web Services
    aws = {
      source  = "hashicorp/aws"  # Official AWS provider
      version = "~> 5.0"         # Use version 5.x (latest stable)
    }
  }

  # Optional: Store Terraform state remotely (uncomment for team projects)
  # backend "s3" {
  #   bucket = "codedetect-terraform-state"
  #   key    = "prod/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# ----------------------------------------------------------------------------
# AWS PROVIDER CONFIGURATION
# ----------------------------------------------------------------------------
# Configure how Terraform connects to AWS
provider "aws" {
  region = var.aws_region  # Which AWS region to use (e.g., us-east-1)

  # Tags applied to ALL resources created by this Terraform config
  default_tags {
    tags = {
      Project     = "CodeDetect"           # Project name
      Environment = var.environment        # dev, staging, or prod
      ManagedBy   = "Terraform"           # Shows this is automated
      Owner       = var.owner_email       # Your email
       # When it was created
    }
  }
}

# ----------------------------------------------------------------------------
# DATA SOURCES
# ----------------------------------------------------------------------------
# Fetch information about existing AWS resources

# Get list of available AWS availability zones in current region
data "aws_availability_zones" "available" {
  state = "available"  # Only zones that are currently operational
}

# Get the latest Amazon Linux 2 AMI (machine image) for EC2
data "aws_ami" "amazon_linux_2" {
  most_recent = true  # Get the newest version
  owners      = ["amazon"]  # Official Amazon AMIs

  # Filter to find exactly what we want
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]  # Amazon Linux 2, 64-bit
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]  # Hardware virtual machine (faster)
  }
}

# Get current AWS account ID (useful for IAM policies)
data "aws_caller_identity" "current" {}

# Get current AWS region information
data "aws_region" "current" {}

# ----------------------------------------------------------------------------
# LOCAL VALUES
# ----------------------------------------------------------------------------
# Define local variables used throughout the configuration

locals {
  # Application name - used in resource naming
  app_name = "codedetect"

  # Common name prefix for all resources
  # Example: "codedetect-prod-vpc"
  name_prefix = "${local.app_name}-${var.environment}"

  # Common tags to apply to all resources
  common_tags = {
    Application = local.app_name
    Environment = var.environment
  }

  # Database configuration
  db_name     = replace(local.app_name, "-", "_")  # Database names can't have hyphens
  db_port     = 5432  # Standard PostgreSQL port

  # Network configuration
  vpc_cidr = "10.0.0.0/16"  # VPC IP range (65,536 IPs)
}

# ============================================================================
# COMMENTS FOR UNDERSTANDING TERRAFORM
# ============================================================================

# WHAT IS TERRAFORM?
# - Infrastructure as Code (IaC) tool
# - Describes AWS resources in code instead of clicking in console
# - Can create, update, and destroy infrastructure automatically

# KEY CONCEPTS:
# 
# 1. RESOURCES
#    - Things you want to create (EC2, RDS, S3, etc.)
#    - Syntax: resource "type" "name" { config }
#
# 2. DATA SOURCES
#    - Information about existing resources
#    - Read-only, doesn't create anything
#
# 3. VARIABLES
#    - Inputs you can change (region, instance size, etc.)
#    - Defined in variables.tf
#
# 4. OUTPUTS
#    - Information displayed after Terraform runs
#    - Defined in outputs.tf
#
# 5. LOCALS
#    - Calculated values used internally
#    - Like variables but computed from other values

# TERRAFORM WORKFLOW:
# 1. terraform init     → Download providers, prepare
# 2. terraform plan     → Preview what will be created
# 3. terraform apply    → Actually create the resources
# 4. terraform destroy  → Delete everything

# WHY USE TERRAFORM?
# - Repeatable: Run same code on different accounts/regions
# - Version Control: Track changes in Git
# - Documentation: Code explains infrastructure
# - Safe: Preview changes before applying
# - Powerful: Create complex infrastructure quickly

# ============================================================================