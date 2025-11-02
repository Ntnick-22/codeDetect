# CodeDetect Infrastructure Project

## Project Overview

This is a **Terraform infrastructure-as-code project** that provisions AWS resources for the CodeDetect application - a code plagiarism detection system. The infrastructure is designed to be simple, cost-effective, and suitable for a small-scale production deployment or MVP.

## Architecture Summary

```
Internet
    ↓
Elastic IP (Static)
    ↓
EC2 Instance (t3.micro)
    ↓ (writes to)
S3 Bucket (file uploads)
```

### Key Components

1. **VPC & Networking** - Custom Virtual Private Cloud with public/private subnets
2. **EC2 Instance** - Single t3.micro instance running Docker
3. **S3 Bucket** - Stores uploaded files for plagiarism checking
4. **Security Groups** - Firewall rules for SSH, HTTP, HTTPS
5. **Elastic IP** - Static IP address for consistent DNS pointing
6. **IAM Roles** - Allows EC2 to securely access S3 without hardcoded credentials

## Current Infrastructure Files

Based on the project structure, you should have these Terraform files:

- `ec2.tf` - EC2 instance, Elastic IP, IAM roles, user data script
- `vpc.tf` - VPC, subnets, Internet Gateway, route tables (likely)
- `security_groups.tf` - Security group rules for EC2 (likely)
- `s3.tf` - S3 bucket for file uploads (likely)
- `variables.tf` - Input variables
- `outputs.tf` - Output values (IPs, DNS, etc.)
- `locals.tf` - Local values and common tags (likely)
- `data.tf` - Data sources like AMI lookups (likely)

## EC2 Instance Details

### Specifications
- **Type**: t3.micro (2 vCPU, 1 GB RAM)
- **OS**: Amazon Linux 2
- **Storage**: 20 GB gp3 SSD (encrypted)
- **Key Components Installed**:
  - Docker
  - Docker Compose
  - Git

### User Data Script
The EC2 instance automatically runs a setup script on first boot that:
1. Updates system packages
2. Installs and starts Docker
3. Installs Docker Compose
4. Installs Git
5. Creates app directory at `/home/ec2-user/app`
6. Adds ec2-user to docker group (no sudo needed)

### SSH Access
- Uses key pair: `codedetect-key`
- Public key file: `codedetect-key.pub` (should be in terraform directory)
- Private key file: `codedetect-key` (keep secure, not in version control!)
- SSH command: `ssh -i codedetect-key ec2-user@<ELASTIC_IP>`

## S3 Bucket

The S3 bucket stores uploaded files for plagiarism detection.

### IAM Permissions
The EC2 instance has an IAM role that grants:
- `s3:GetObject` - Read files
- `s3:PutObject` - Upload files
- `s3:DeleteObject` - Delete files
- `s3:ListBucket` - List bucket contents

**Security Note**: No hardcoded AWS credentials needed in application code!

## Security Configuration

### EC2 Security Group (Expected Rules)
- **Port 22** (SSH) - For remote access
- **Port 80** (HTTP) - For web traffic
- **Port 443** (HTTPS) - For secure web traffic
- **Port 3000** (App) - For CodeDetect application (if applicable)

### Best Practices Implemented
- ✅ Encrypted EBS volumes
- ✅ IAM roles instead of hardcoded credentials
- ✅ SSH key-based authentication
- ✅ VPC isolation
- ⚠️ SSH should be restricted to your IP (not 0.0.0.0/0)

## Deployment Workflow

### Prerequisites
```bash
# Required tools
terraform >= 1.0
aws-cli configured with credentials
ssh-keygen (to create key pair)

# Generate SSH key pair if not exists
ssh-keygen -t rsa -b 2048 -f codedetect-key
# This creates: codedetect-key (private) and codedetect-key.pub (public)
```

### Standard Deployment Commands
```bash
# 1. Initialize Terraform (first time only)
terraform init

# 2. Review what will be created
terraform plan

# 3. Create the infrastructure
terraform apply

# 4. Get the Elastic IP from outputs
terraform output elastic_ip

# 5. SSH into the server
ssh -i codedetect-key ec2-user@<ELASTIC_IP>

# 6. Deploy your application
cd /home/ec2-user/app
git clone https://github.com/yourusername/codedetect.git .
docker-compose up -d
```

### Tear Down
```bash
# Destroy all resources (careful!)
terraform destroy
```

## Variables Configuration

Key variables you should set in `terraform.tfvars` or pass via `-var`:

```hcl
# terraform.tfvars example
aws_region       = "eu-west-1"
environment      = "production"
project_name     = "codedetect"
instance_type    = "t3.micro"
key_pair_name    = "codedetect-key"
enable_monitoring = false  # Set true for detailed CloudWatch metrics
```

## Common Tasks & How to Ask Claude Code

### Making Changes
```
"Add a second EC2 instance in a different availability zone"
"Update the instance type to t3.small for better performance"
"Add CloudWatch alarms for high CPU usage"
"Create an Application Load Balancer in front of the EC2"
```

### Adding Features
```
"Add an RDS PostgreSQL database with proper security groups"
"Set up auto-scaling for the EC2 instances"
"Add a CloudFront distribution for static assets"
"Create a backup policy for the S3 bucket"
```

### Debugging
```
"I'm getting 'invalid AMI' error, can you help?"
"The EC2 instance won't start, check the user data script"
"Security group is blocking traffic on port 3000, fix it"
```

### Code Review
```
"Review this Terraform code for security vulnerabilities"
"Check if we're following AWS best practices"
"Suggest cost optimizations for this infrastructure"
```

## Cost Estimate (Approximate Monthly)

- **EC2 t3.micro**: ~$8/month (Free Tier: 750 hours/month for 12 months)
- **EBS 20GB gp3**: ~$2/month
- **Elastic IP**: Free (while attached to running instance)
- **S3 Storage**: ~$0.023/GB/month + requests
- **Data Transfer**: First 100 GB/month free

**Total**: ~$10-15/month (excluding S3 usage and data transfer)

## Troubleshooting Guide

### "Permission denied" when SSH
- Check key file permissions: `chmod 400 codedetect-key`
- Verify you're using correct username: `ec2-user` (not `ubuntu` or `root`)
- Confirm security group allows SSH from your IP

### "Connection timeout" when SSH
- Security group may not allow SSH from your IP
- Instance may not be in public subnet
- Internet Gateway may not be attached
- Check instance is in "running" state

### Docker commands require sudo
- User data script adds user to docker group, but requires logout/login
- SSH out and back in, or run: `newgrp docker`

### Can't access web application
- Check security group allows HTTP/HTTPS
- Verify application is running: `docker ps`
- Check application logs: `docker-compose logs`

## Future Enhancements

Potential improvements to consider:

1. **High Availability**
   - Multiple EC2 instances across AZs
   - Application Load Balancer
   - Auto Scaling Group

2. **Database**
   - RDS PostgreSQL/MySQL
   - Redis for caching
   - Database backups

3. **Monitoring & Logging**
   - CloudWatch dashboards
   - CloudWatch Alarms
   - Centralized logging (CloudWatch Logs)

4. **CI/CD**
   - GitHub Actions for deployment
   - Automated Terraform apply
   - Docker image building pipeline

5. **Security Hardening**
   - WAF (Web Application Firewall)
   - AWS Secrets Manager for secrets
   - VPN/Bastion host for SSH access
   - AWS Certificate Manager for SSL

6. **Backup & Disaster Recovery**
   - Automated EBS snapshots
   - S3 versioning and replication
   - Infrastructure state backup

## Important Notes for Claude Code

### When Editing This Infrastructure:

1. **Always run `terraform plan` before `terraform apply`** to see what changes will be made
2. **Never commit sensitive files**: `codedetect-key`, `codedetect-key.pub`, `terraform.tfvars`
3. **State file is critical**: `terraform.tfstate` tracks all resources - back it up!
4. **Destroy carefully**: `terraform destroy` will delete EVERYTHING including data
5. **Test changes in dev first**: Consider having separate `dev` and `prod` environments

### Terraform Best Practices:
- Use variables for configurable values
- Add tags to all resources for organization
- Enable versioning on S3 buckets
- Use remote state backend (S3 + DynamoDB) for team collaboration
- Pin provider versions in `versions.tf`

### AWS Best Practices:
- Principle of least privilege for IAM roles
- Enable MFA for AWS account
- Use AWS Organizations for multi-account setup
- Enable CloudTrail for audit logging
- Regular security audits with AWS Trusted Advisor

## Quick Reference Commands

```bash
# Terraform
terraform init              # Initialize working directory
terraform plan              # Preview changes
terraform apply             # Apply changes
terraform destroy           # Destroy infrastructure
terraform output            # Show output values
terraform state list        # List resources in state

# AWS CLI
aws ec2 describe-instances  # List EC2 instances
aws s3 ls                   # List S3 buckets
aws ec2 describe-security-groups  # List security groups

# SSH & Server Management
ssh -i codedetect-key ec2-user@<IP>  # Connect to server
sudo systemctl status docker          # Check Docker status
docker ps                             # List running containers
docker-compose logs -f                # View application logs
```

## Project Status

**Current State**: Basic infrastructure setup with single EC2 instance
**Environment**: Production/MVP
**Last Updated**: November 2025

---

## Resources & Documentation

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Docker Documentation](https://docs.docker.com/)
- [CodeDetect Application Repo](https://github.com/yourusername/codedetect) *(update with actual repo)*

---

**Note to Claude Code**: This infrastructure is for a production/MVP deployment. Please ask for confirmation before making changes that could cause downtime or data loss. Always suggest reviewing changes with `terraform plan` first.
