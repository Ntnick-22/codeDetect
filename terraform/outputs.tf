# ============================================================================
# TERRAFORM OUTPUTS
# ============================================================================
# Displays important information after infrastructure is created
# Run 'terraform output' to see these values anytime
# ============================================================================

# ----------------------------------------------------------------------------
# EC2 INSTANCE INFORMATION - Now using Auto Scaling Group
# ----------------------------------------------------------------------------

# COMMENTED OUT: Now using Auto Scaling Group instead of single instance
# output "ec2_instance_id" {
#   description = "ID of the EC2 instance"
#   value       = aws_instance.main.id
# }

# output "ec2_public_ip" {
#   description = "Removed - Using Auto Scaling Group with Load Balancer"
#   value       = "See load_balancer_dns output"
# }

# output "ec2_instance_type" {
#   description = "Type of EC2 instance"
#   value       = aws_instance.main.instance_type
# }

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
  value       = var.enable_dns ? data.aws_route53_zone.main[0].name_servers : []
}

# ----------------------------------------------------------------------------
# SSH CONNECTION INFORMATION
# ----------------------------------------------------------------------------

output "ssh_connection_command" {
  description = "Command to SSH into EC2 instances (use instance IPs from AWS Console)"
  value       = "aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=${local.active_asg_name}' --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' --output table"
}

output "ssh_key_name" {
  description = "Name of SSH key pair"
  value       = data.aws_key_pair.main.key_name
}

# ----------------------------------------------------------------------------
# APPLICATION DEPLOYMENT COMMANDS
# ----------------------------------------------------------------------------

output "deployment_commands" {
  description = "Commands to deploy your application"
  value       = <<-EOT
    # With Auto Scaling Group, deployment is automated via instance refresh
    # To trigger deployment:

    # 1. Push code to GitHub
    git push origin main

    # 2. Trigger instance refresh (zero-downtime rolling update)
    aws autoscaling start-instance-refresh \
      --auto-scaling-group-name ${local.active_asg_name} \
      --preferences MinHealthyPercentage=50

    # 3. Monitor refresh status
    aws autoscaling describe-instance-refreshes \
      --auto-scaling-group-name ${local.active_asg_name}

    # Note: Manual SSH deployment not recommended with Auto Scaling
    # If needed for debugging, get instance IPs:
    # aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=${local.active_asg_name}' --query 'Reservations[*].Instances[*].PublicIpAddress' --output text
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
    region            = var.aws_region
    environment       = var.environment
    ec2_instance_type = var.instance_type
    s3_bucket         = aws_s3_bucket.uploads.id
    domain_url        = var.subdomain != "" ? "http://${var.subdomain}.${var.domain_name}" : "http://${var.domain_name}"
    estimated_cost    = "~$2-10/month (depending on free tier eligibility)"
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
# MONITORING & ALERTING INFORMATION
# ----------------------------------------------------------------------------

output "sns_topic_arn" {
  description = "ARN of SNS topic for monitoring alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_feedback_topic_arn" {
  description = "ARN of SNS topic for user feedback"
  value       = aws_sns_topic.user_feedback.arn
}

output "notification_email" {
  description = "Email address receiving alerts"
  value       = var.notification_email
}

output "cloudwatch_alarms" {
  description = "List of CloudWatch alarms created"
  value = {
    blue_cpu_high_alarm = aws_cloudwatch_metric_alarm.blue_cpu_high.alarm_name
    green_cpu_high_alarm = aws_cloudwatch_metric_alarm.green_cpu_high.alarm_name
    instance_down_alarm = aws_cloudwatch_metric_alarm.instance_status_check.alarm_name
    high_network_alarm  = aws_cloudwatch_metric_alarm.high_network_out.alarm_name
  }
}

output "cloudwatch_alarms_url" {
  description = "Direct link to CloudWatch Alarms in AWS Console"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:"
}

output "cloudwatch_dashboard_url" {
  description = "Direct link to CloudWatch Dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "monitoring_setup_instructions" {
  description = "Instructions to complete monitoring setup"
  value       = <<-EOT
    ⚠️  IMPORTANT: Complete SNS Email Subscription

    After running 'terraform apply':

    1. CHECK YOUR EMAIL: ${var.notification_email}
       Subject: "AWS Notification - Subscription Confirmation"
       (Check spam folder if not in inbox)

    2. CLICK "Confirm subscription" link in email
       Until you confirm, you won't receive any alerts!

    3. VERIFY SUBSCRIPTION:
       aws sns list-subscriptions-by-topic --topic-arn ${aws_sns_topic.alerts.arn}
       Should show "SubscriptionArn" (not "PendingConfirmation")

    4. TEST AN ALARM (optional):
       aws cloudwatch set-alarm-state \
         --alarm-name ${aws_cloudwatch_metric_alarm.blue_cpu_high.alarm_name} \
         --state-value ALARM \
         --state-reason "Testing alarm notification"

       You should receive test email + SMS within 1 minute.

    Monitoring Dashboard: ${aws_sns_topic.alerts.arn}

    Active Alarms:
    ✓ High CPU (>80% for 5 min)
    ✓ Instance Down (status check fails)
    ✓ High Network Traffic (>100MB/5min)
  EOT
}

# ----------------------------------------------------------------------------
# COST ESTIMATION OUTPUT
# ----------------------------------------------------------------------------

output "monthly_cost_estimate" {
  description = "Estimated monthly AWS costs"
  value       = <<-EOT
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
  value       = <<-EOT
    ✅ Infrastructure Created Successfully!
    
    Next Steps:
    
    1. VERIFY DNS PROPAGATION (wait 5-10 minutes)
       Check: https://dnschecker.org
       Domain: ${var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name}

    2. CHECK LOAD BALANCER
       URL: ${aws_lb.main.dns_name}
       Health: All targets should be healthy

    3. CHECK AUTO SCALING GROUP
       Instances: Should have 2+ healthy instances
       Command: aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${local.active_asg_name}

    4. TEST YOUR APPLICATION
       HTTPS: https://${var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name}
       HTTP redirects automatically to HTTPS

    5. MONITOR EFS DATABASE
       Database on shared storage: /mnt/efs/database/codedetect.db
       Both instances use same database

    6. SSH FOR DEBUGGING (if needed)
       Get instance IPs: aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=${local.active_asg_name}' --query 'Reservations[*].Instances[*].PublicIpAddress' --output text
       SSH: ssh -i codedetect-key ec2-user@<INSTANCE_IP>

    7. TEST APPLICATION
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