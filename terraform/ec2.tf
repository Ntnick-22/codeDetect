resource "aws_key_pair" "main" {
  key_name   = var.key_pair_name
  public_key = file("${path.module}/codedetect-key.pub")  # Your public key file

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-key"
    }
  )

  # If you don't have a key yet, comment out this resource
  # and create manually in AWS Console first
}

# ----------------------------------------------------------------------------
# ELASTIC IP
# ----------------------------------------------------------------------------
# Static public IP address that doesn't change when you restart EC2
# Important for DNS (your domain always points to same IP)

resource "aws_eip" "main" {
  domain = "vpc"  # Allocate in VPC

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-eip"
    }
  )

  # Depends on Internet Gateway existing first
  depends_on = [aws_internet_gateway.main]
}

# Associate Elastic IP with EC2 instance
resource "aws_eip_association" "main" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main.id
}

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
    
    # Create app directory
    mkdir -p /home/ec2-user/app
    chown ec2-user:ec2-user /home/ec2-user/app
    
    # Log completion
    echo "CodeDetect setup complete!" > /home/ec2-user/setup-complete.txt
    
    # Optional: Auto-clone your repo and start app
    # cd /home/ec2-user/app
    # git clone https://github.com/yourusername/codedetect.git .
    # docker-compose up -d
  EOF
}

# ----------------------------------------------------------------------------
# EC2 INSTANCE
# ----------------------------------------------------------------------------
# The main server that runs your application

resource "aws_instance" "main" {
  # AMI (machine image) - using Amazon Linux 2
  ami           = data.aws_ami.amazon_linux_2.id
  
  # Instance type (size)
  instance_type = var.instance_type  # t3.micro from variables
  
  # SSH key for access
  key_name      = aws_key_pair.main.key_name
  
  # Which subnet to launch in (public subnet 1)
  subnet_id     = aws_subnet.public_1.id
  
  # Security group (firewall rules)
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  # User data script (runs on first boot)
  user_data = local.user_data
  
  # Root volume (main hard drive)
  root_block_device {
    volume_type = "gp3"     # General Purpose SSD v3 (faster, cheaper)
    volume_size = 20        # 20 GB (enough for Docker + app)
    encrypted   = true      # Encrypt the drive for security
    
    tags = {
      Name = "${local.name_prefix}-root-volume"
    }
  }
  
  # Enable detailed monitoring (optional, costs extra)
  monitoring = var.enable_monitoring
  
  # IAM role for accessing S3 (we'll create this next)
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2"
    }
  )
  
  # Ensure VPC and security group exist first
  depends_on = [
    aws_security_group.ec2,
    aws_internet_gateway.main
  ]
}

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