# ============================================================================
# TERRAFORM OUTPUTS
# ============================================================================
# Displays important information after infrastructure is created
# Run 'terraform output' to see these values anytime
# ============================================================================

# ----------------------------------------------------------------------------
# EC2 INSTANCE INFORMATION
# ----------------------------------------------------------------------------

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "ec2_public_ip" {
  description = "Public IP address of EC2 instance (Elastic IP)"
  value       = aws_eip.main.public_ip
}

output "ec2_instance_type" {
  description = "Type of EC2 instance"
  value       = aws_instance.main.instance_type
}

# ----------------------------------------------------------------------------
# NETWORK INFORMATION
# ----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "security_group_id" {
  description = "ID of EC2 security group"
  value       = aws_security_group.ec2.id
}

# ----------------------------------------------------------------------------
# S3 BUCKET INFORMATION
# ----------------------------------------------------------------------------

output "s3_bucket_name" {
  description = "Name of S3 bucket for uploads"
  value       = aws_s3_bucket.uploads.id
}

output "s3_bucket_arn" {
  description = "ARN of S3 bucket"
  value       = aws_s3_bucket.uploads.arn
}

output "s3_bucket_region" {
  description = "AWS region where S3 bucket is located"
  value       = aws_s3_bucket.uploads.region
}

# ----------------------------------------------------------------------------
# DOMAIN & DNS INFORMATION
# ----------------------------------------------------------------------------

output "app_url" {
  description = "URL to access your application"
  value       = var.subdomain != "" ? "http://${var.subdomain}.${var.domain_name}" : "http://${var.domain_name}"
}

output "app_url_with_port" {
  description = "URL with port (if not using port 80)"
  value       = var.subdomain != "" ? "http://${var.subdomain}.${var.domain_name}:5000" : "http://${var.domain_name}:5000"
}

output "route53_nameservers" {
  description = "Nameservers for your Route 53 hosted zone"
  value       = data.aws_route53_zone.main.name_servers
}

# ----------------------------------------------------------------------------
# SSH CONNECTION INFORMATION
# ----------------------------------------------------------------------------

output "ssh_connection_command" {
  description = "Command to SSH into EC2 instance"
  value       = "ssh -i codedetect-key ec2-user@${aws_eip.main.public_ip}"
}

output "ssh_key_name" {
  description = "Name of SSH key pair"
  value       = aws_key_pair.main.key_name
}

# ----------------------------------------------------------------------------
# APPLICATION DEPLOYMENT COMMANDS
# ----------------------------------------------------------------------------

output "deployment_commands" {
  description = "Commands to deploy your application"
  value = <<-EOT
    # 1. SSH into EC2
    ssh -i codedetect-key ec2-user@${aws_eip.main.public_ip}
    
    # 2. Clone your repository
    cd /home/ec2-user/app
    git clone https://github.com/yourusername/codedetect.git .
    
    # 3. Configure environment
    export DATABASE_URL=sqlite:///instance/codedetect.db
    export S3_BUCKET_NAME=${aws_s3_bucket.uploads.id}
    
    # 4. Start application with Docker
    docker-compose up -d
    
    # 5. Check if running
    docker ps
    
    # 6. View logs
    docker-compose logs -f
  EOT
}

# ----------------------------------------------------------------------------
# INFRASTRUCTURE SUMMARY
# ----------------------------------------------------------------------------

output "infrastructure_summary" {
  description = "Summary of created infrastructure"
  value = {
    region              = var.aws_region
    environment         = var.environment
    ec2_instance_type   = var.instance_type
    s3_bucket          = aws_s3_bucket.uploads.id
    domain_url         = var.subdomain != "" ? "http://${var.subdomain}.${var.domain_name}" : "http://${var.domain_name}"
    estimated_cost     = "~$2-10/month (depending on free tier eligibility)"
  }
}

# ============================================================================
# OUTPUT EXPLANATION
# ============================================================================

# WHAT ARE OUTPUTS?
# - Values displayed after 'terraform apply' completes
# - Can be viewed anytime with 'terraform output'
# - Useful for getting important information without digging through resources

# HOW TO USE OUTPUTS:
# 
# View all outputs:
#   terraform output
#
# View specific output:
#   terraform output ec2_public_ip
#
# Get output as JSON:
#   terraform output -json
#
# Use in scripts:
#   EC2_IP=$(terraform output -raw ec2_public_ip)

# WHY OUTPUTS ARE USEFUL:
# - Remember important values (IPs, URLs, bucket names)
# - Use in automation scripts
# - Share info with team members
# - Copy-paste SSH commands
# - Documentation

# SENSITIVE OUTPUTS:
# - Add 'sensitive = true' to hide value in logs
# - Use for passwords, keys, secrets
# - Example:
#   output "db_password" {
#     value     = var.db_password
#     sensitive = true
#   }

# ============================================================================

# ----------------------------------------------------------------------------
# COST ESTIMATION OUTPUT
# ----------------------------------------------------------------------------

output "monthly_cost_estimate" {
  description = "Estimated monthly AWS costs"
  value = <<-EOT
    Estimated Monthly Costs (EU-WEST-1):
    
    With Free Tier (First 12 Months):
    - EC2 t3.micro:        $0.00  (750 hours/month free)
    - S3 Storage (5GB):    $0.00  (free tier)
    - Route 53 Hosted Zone: $0.50  (not covered by free tier)
    - Data Transfer (1GB): $0.00  (free tier)
    TOTAL: ~$1-2/month
    
    After Free Tier:
    - EC2 t3.micro:        ~$7.50/month
    - S3 Storage:          ~$0.50/month
    - Route 53:            $0.50/month
    - Data Transfer:       ~$1/month
    TOTAL: ~$10/month
    
    Note: Actual costs may vary based on usage.
    Monitor costs in AWS Cost Explorer!
  EOT
}

# ----------------------------------------------------------------------------
# NEXT STEPS OUTPUT
# ----------------------------------------------------------------------------

output "next_steps" {
  description = "What to do after Terraform completes"
  value = <<-EOT
    ✅ Infrastructure Created Successfully!
    
    Next Steps:
    
    1. VERIFY DNS PROPAGATION (wait 5-10 minutes)
       Check: https://dnschecker.org
       Domain: ${var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name}
    
    2. SSH INTO EC2
     ssh -i codedetect-key ec2-user@${aws_eip.main.public_ip}
    
    3. DEPLOY YOUR APPLICATION
       - Clone your Git repository
       - Configure environment variables
       - Run: docker-compose up -d
    
    4. TEST YOUR APPLICATION
       URL: ${var.subdomain != "" ? "http://${var.subdomain}.${var.domain_name}:5000" : "http://${var.domain_name}:5000"}
    
    5. CONFIGURE FIREWALL (if needed)
       - Update security group rules
       - Allow port 80 for standard HTTP
    
    6. MONITOR COSTS
       - AWS Console → Billing Dashboard
       - Set up billing alerts
    
    7. SETUP BACKUPS
       - Enable automated snapshots
       - Test restore procedures
    
    Happy Deploying! 🚀
  EOT
}

# ============================================================================