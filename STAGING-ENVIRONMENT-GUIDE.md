# Staging Environment Setup Guide

## Why You Need a Staging Environment

### The Problem You're Facing:

```
❌ Current Workflow (Risky):
Change code → Push to GitHub → Deploy to Production → 💥 Server Down!
                                                        ↓
                                                   Users affected!
```

### The Solution:

```
✅ Proper Workflow (Safe):
Change code → Push to GitHub → Deploy to STAGING → Test thoroughly
                                      ↓
                                   Works? ✓
                                      ↓
                              Deploy to PRODUCTION → Users happy! 😊
```

---

## What is a Staging Environment?

**Staging** is a **copy** of your production environment where you can:
- ✅ Test new features before going live
- ✅ Test infrastructure changes safely
- ✅ Catch bugs before users see them
- ✅ Train on deployments without risk
- ✅ Show demos without affecting production

**Think of it as a "practice server"** - identical to production, but isolated.

---

## Three-Environment Strategy

### Industry Standard Approach:

| Environment | Purpose | Who Uses It | Uptime |
|-------------|---------|-------------|--------|
| **Development (Dev)** | Active development, frequent changes | Developers only | Can be down often |
| **Staging (Stage)** | Pre-production testing, identical to prod | Developers + QA | Should be stable |
| **Production (Prod)** | Live application serving real users | End users | Must be always up! |

---

## Option 1: Terraform Workspaces (Recommended for You)

### What are Terraform Workspaces?

Workspaces let you manage **multiple environments** using the **same Terraform code**.

**Benefits:**
- ✅ Same infrastructure code for all environments
- ✅ Easy to switch between environments
- ✅ Separate state files for each environment
- ✅ Cost-effective (spin up staging only when needed)

### Architecture:

```
Your Terraform Code (terraform/*.tf)
        ↓
    Workspaces:
    ├── default (production)
    ├── staging
    └── dev

Each workspace creates SEPARATE:
- EC2 instances
- Load balancers
- Databases
- S3 buckets
- Everything!
```

---

## Step-by-Step: Setting Up Staging with Terraform Workspaces

### Step 1: Check Current Workspace

```bash
cd terraform

# See available workspaces
terraform workspace list

# Output:
# * default  ← You're currently here (production)
```

The `*` shows your current workspace.

---

### Step 2: Create Staging Workspace

```bash
# Create and switch to staging workspace
terraform workspace new staging

# Output:
# Created and switched to workspace "staging"!

# Verify
terraform workspace list

# Output:
#   default
# * staging  ← You're now in staging
```

**What just happened?**
- Terraform created a new isolated environment
- Separate state file: `terraform.tfstate.d/staging/terraform.tfstate`
- Nothing deployed yet - just the workspace created

---

### Step 3: Modify Variables for Staging

Create a staging-specific variables file:

```bash
# Create staging variables file
cd terraform
```

**Create file:** `terraform/staging.tfvars`

```hcl
# Staging Environment Configuration
# This file defines settings for staging environment

# Environment name
environment = "staging"

# AWS Region (can be different from prod)
aws_region = "eu-west-1"

# Instance Configuration
# Use smaller/cheaper instances for staging
instance_type = "t3.micro"  # Same as prod, or t3.nano to save costs

# Scaling Configuration
# Staging doesn't need high availability
# Use 1 instance to save costs
active_environment = "blue"  # Start with blue

# S3 Bucket (MUST be unique globally!)
s3_bucket_name = "codedetect-staging-uploads"  # Different from prod

# Database Name
db_name = "codedetect_staging"

# Docker Configuration
# Test new versions here first!
docker_image_repo = "ntnick/codedetect"
docker_tag = "staging-latest"  # Or specific version to test

# Monitoring (disable to save costs)
enable_monitoring = false

# RDS Configuration
use_rds = false  # Use SQLite for staging to save costs

# Domain Configuration (if using Route53)
enable_dns = false  # Staging doesn't need custom domain
# Or use subdomain: staging.codedetect.com

# Key Pair (reuse same SSH key)
key_pair_name = "codedetect-key"

# Cost Optimization: Auto-shutdown staging at night?
# (We'll set this up later with Lambda if needed)
```

**Save this file as:** `terraform/staging.tfvars`

---

### Step 4: Deploy Staging Environment

```bash
# Make sure you're in staging workspace
terraform workspace show
# Output: staging

# Preview what will be created
terraform plan -var-file="staging.tfvars"

# Review carefully - should create NEW resources (not modify prod!)
# Look for: Plan: X to add, 0 to change, 0 to destroy

# Deploy staging environment
terraform apply -var-file="staging.tfvars"

# Type: yes
```

**What gets created:**
- ✅ New VPC (isolated network)
- ✅ New EC2 instances
- ✅ New Load Balancer (different DNS)
- ✅ New S3 bucket
- ✅ New security groups
- ✅ Everything separate from production!

**Wait 5-10 minutes** for deployment to complete.

---

### Step 5: Get Staging URLs

```bash
# Get staging load balancer URL
terraform output load_balancer_url

# Output example:
# http://codedetect-staging-alb-123456.eu-west-1.elb.amazonaws.com

# Save this URL! This is your staging server
```

**Test it:**
```bash
# Open in browser or curl
curl http://codedetect-staging-alb-XXXXX.eu-west-1.elb.amazonaws.com/api/health

# Should return: {"status": "healthy"}
```

---

### Step 6: Test Changes in Staging

Now you can safely test changes!

#### Example: Testing New Feature

```bash
# 1. Write code locally
# 2. Build Docker image with staging tag
docker build -t ntnick/codedetect:staging-test-feature .

# 3. Push to Docker Hub
docker push ntnick/codedetect:staging-test-feature

# 4. Update staging environment
terraform workspace select staging

# 5. Update staging.tfvars with new tag
# docker_tag = "staging-test-feature"

# 6. Deploy to staging
terraform apply -var-file="staging.tfvars"

# 7. Test on staging URL
# If it works ✓ → Deploy to production
# If it breaks ✗ → Fix code, redeploy to staging
```

**Production is safe!** Users never see the bug.

---

### Step 7: Switching Between Environments

```bash
# Switch to staging
terraform workspace select staging
terraform workspace show
# Output: staging

# Work on staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"

# Switch back to production
terraform workspace select default
terraform workspace show
# Output: default

# Work on production
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

**⚠️ IMPORTANT:** Always verify which workspace you're in before running `terraform apply`!

---

## Option 2: Separate AWS Accounts (Enterprise Approach)

For maximum isolation, use separate AWS accounts:

```
AWS Organization
├── Production Account (123456789012)
│   └── Production infrastructure
├── Staging Account (234567890123)
│   └── Staging infrastructure
└── Development Account (345678901234)
    └── Dev infrastructure
```

**Benefits:**
- ✅ Complete isolation (can't accidentally delete prod)
- ✅ Separate billing (know staging costs)
- ✅ Different permissions (devs can't touch prod)

**Drawbacks:**
- ❌ More complex setup
- ❌ Need multiple AWS accounts
- ❌ More expensive (resources can't be shared)

**Recommendation:** Start with **Terraform Workspaces**, upgrade to separate accounts later if needed.

---

## Option 3: Different Regions (Geographic Isolation)

Deploy staging in different AWS region:

```hcl
# terraform/staging.tfvars
aws_region = "us-east-1"  # Staging in US

# terraform/terraform.tfvars (production)
aws_region = "eu-west-1"  # Production in EU
```

**Benefits:**
- ✅ Complete network isolation
- ✅ Test multi-region setup
- ✅ Practice disaster recovery

**Drawbacks:**
- ❌ Data transfer costs between regions
- ❌ Can't share resources (EFS, RDS snapshots)

---

## CI/CD for Staging Environment

### Update GitHub Actions for Multi-Environment

Create separate workflows for staging and production:

#### File: `.github/workflows/deploy-staging.yml`

```yaml
name: Deploy to Staging

on:
  push:
    branches:
      - develop  # Trigger on develop branch
      - staging

jobs:
  deploy-staging:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push Docker image
        run: |
          docker build -t ntnick/codedetect:staging-${{ github.sha }} .
          docker push ntnick/codedetect:staging-${{ github.sha }}

          # Also tag as staging-latest
          docker tag ntnick/codedetect:staging-${{ github.sha }} ntnick/codedetect:staging-latest
          docker push ntnick/codedetect:staging-latest

      - name: Deploy to Staging EC2
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.STAGING_EC2_HOST }}  # Staging server IP
          username: ec2-user
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /home/ec2-user/app
            docker pull ntnick/codedetect:staging-latest
            docker-compose down
            docker-compose up -d
            docker system prune -f
```

#### File: `.github/workflows/deploy-production.yml`

```yaml
name: Deploy to Production

on:
  push:
    branches:
      - main  # Only trigger on main branch
  workflow_dispatch:  # Allow manual trigger

jobs:
  deploy-production:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push Docker image
        run: |
          docker build -t ntnick/codedetect:blue-${{ github.sha }} .
          docker push ntnick/codedetect:blue-${{ github.sha }}

      - name: Deploy to Production EC2
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PRODUCTION_EC2_HOST }}  # Production server IP
          username: ec2-user
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /home/ec2-user/app
            docker pull ntnick/codedetect:blue-${{ github.sha }}
            docker-compose down
            docker-compose up -d
            docker system prune -f
```

### Git Branch Strategy

```
main (production)
  ↑
  └── Pull Request (after testing)
        ↑
develop/staging (staging)
  ↑
  └── Feature branches
```

**Workflow:**
1. Create feature branch from `develop`
2. Make changes
3. Push to `develop` → Deploys to **staging** automatically
4. Test on staging
5. If OK, create PR to merge `develop` → `main`
6. Merge PR → Deploys to **production** automatically

---

## Cost Comparison

### Scenario 1: Staging Always Running

| Resource | Production | Staging | Total Monthly |
|----------|-----------|---------|---------------|
| EC2 (t3.micro) | 2 × $8 | 2 × $8 | $32 |
| ALB | $16 | $16 | $32 |
| S3 | $2 | $2 | $4 |
| **Total** | **$26** | **$26** | **$52/month** |

**Doubles your costs!** ⚠️

---

### Scenario 2: Staging On-Demand (Recommended)

Only run staging when testing:

| Resource | Production (24/7) | Staging (8h/week) | Total Monthly |
|----------|-------------------|-------------------|---------------|
| EC2 | 2 × $8 | 2 × $1 | $18 |
| ALB | $16 | $2 | $18 |
| S3 | $2 | $0.20 | $2.20 |
| **Total** | **$26** | **$3.20** | **$29.20/month** |

**Only 12% increase!** ✅

---

### How to Implement On-Demand Staging

```bash
# Before testing: Deploy staging
terraform workspace select staging
terraform apply -var-file="staging.tfvars"

# Test your changes (2-3 hours)
# ...

# After testing: Destroy staging
terraform destroy -var-file="staging.tfvars"

# Switch back to production
terraform workspace select default
```

**Cost:** ~$0.50 per 3-hour testing session

---

## Quick Reference Commands

### Workspace Management

```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new staging

# Switch workspace
terraform workspace select staging
terraform workspace select default

# Show current workspace
terraform workspace show

# Delete workspace (must be empty!)
terraform workspace delete staging
```

### Deployment

```bash
# Deploy to staging
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"

# Deploy to production
terraform workspace select default
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Destroy staging (save costs)
terraform workspace select staging
terraform destroy -var-file="staging.tfvars"
```

### Getting Info

```bash
# Get staging URL
terraform workspace select staging
terraform output load_balancer_url

# Get production URL
terraform workspace select default
terraform output load_balancer_url

# Compare environments
terraform workspace select staging
terraform state list

terraform workspace select default
terraform state list
```

---

## Real-World Workflow Example

### Scenario: Adding New Feature (Code Change)

```bash
# 1. Create feature branch
git checkout -b feature/add-export-feature

# 2. Write code locally
# ... make changes ...

# 3. Build Docker image for staging
docker build -t ntnick/codedetect:staging-export-test .
docker push ntnick/codedetect:staging-export-test

# 4. Deploy staging environment (if not running)
terraform workspace select staging
terraform apply -var-file="staging.tfvars"

# 5. Update staging to use new image
# Edit staging.tfvars: docker_tag = "staging-export-test"
terraform apply -var-file="staging.tfvars"

# 6. Test on staging
curl http://staging-alb-XXXXX.amazonaws.com/api/export
# Test thoroughly!

# 7. If works ✓
git checkout main
git merge feature/add-export-feature
git push origin main
# → CI/CD deploys to production automatically

# 8. Destroy staging to save costs
terraform workspace select staging
terraform destroy -var-file="staging.tfvars"
```

---

### Scenario: Testing Infrastructure Change (Terraform Change)

```bash
# 1. Make Terraform change (e.g., add Redis cache)
# Edit terraform/cache.tf

# 2. Test in staging first
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
# Review: What will be created?

# 3. Apply to staging
terraform apply -var-file="staging.tfvars"

# 4. Test the new infrastructure
# Connect to staging EC2, test Redis connection

# 5. If works ✓
terraform workspace select default
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# 6. Clean up staging
terraform workspace select staging
terraform destroy -var-file="staging.tfvars"
```

---

## Tagging Strategy for Environments

### Docker Image Tags

```bash
# Production tags
ntnick/codedetect:blue-abc1234       # Specific blue deployment
ntnick/codedetect:green-def5678      # Specific green deployment
ntnick/codedetect:v1.2.3             # Version tag

# Staging tags
ntnick/codedetect:staging-latest     # Latest staging build
ntnick/codedetect:staging-abc1234    # Specific staging test
ntnick/codedetect:staging-bugfix-123 # Testing specific fix

# Development tags
ntnick/codedetect:dev-latest         # Latest dev build
ntnick/codedetect:dev-feature-xyz    # Testing feature
```

### AWS Resource Tags

All resources should have environment tag:

```hcl
# terraform/variables.tf
variable "environment" {
  type = string
}

# terraform/main.tf
locals {
  common_tags = {
    Application = "codedetect"
    Environment = var.environment  # "production", "staging", or "dev"
    ManagedBy   = "Terraform"
  }
}
```

**Benefits:**
- Easy to identify resources in AWS Console
- Filter by environment
- Track costs per environment
- Automated cleanup scripts

---

## Monitoring Multiple Environments

### CloudWatch Dashboards

Create separate dashboards:

- `codedetect-production-dashboard`
- `codedetect-staging-dashboard`

### Cost Alerts

Set up separate budgets:

```hcl
# Production budget: $30/month
resource "aws_budgets_budget" "production" {
  name              = "codedetect-production-budget"
  budget_type       = "COST"
  limit_amount      = "30"
  limit_unit        = "USD"
  time_period_start = "2025-01-01_00:00"
  time_unit         = "MONTHLY"

  cost_filters = {
    TagKeyValue = "Environment$production"
  }
}

# Staging budget: $10/month
resource "aws_budgets_budget" "staging" {
  name              = "codedetect-staging-budget"
  budget_type       = "COST"
  limit_amount      = "10"
  limit_unit        = "USD"
  time_period_start = "2025-01-01_00:00"
  time_unit         = "MONTHLY"

  cost_filters = {
    TagKeyValue = "Environment$staging"
  }
}
```

---

## Safety Checklist

Before running `terraform apply`, always check:

- [ ] Which workspace am I in? (`terraform workspace show`)
- [ ] Which var file am I using? (`staging.tfvars` or `terraform.tfvars`)
- [ ] Did I review the plan? (`terraform plan`)
- [ ] Am I okay with these changes?
- [ ] Is this the right environment?

### Add Safety Prompt

Create alias in `.bashrc` or `.zshrc`:

```bash
# Safe terraform apply
alias tf-apply='echo "⚠️  Current workspace: $(terraform workspace show)" && terraform apply'
```

---

## Common Pitfalls

### ❌ Mistake 1: Applying to Wrong Environment

```bash
# You think you're in staging, but you're in production!
terraform apply -var-file="staging.tfvars"
# 💥 Breaks production!
```

**Solution:** Always check workspace first:
```bash
terraform workspace show
```

---

### ❌ Mistake 2: Same S3 Bucket Name

```hcl
# staging.tfvars
s3_bucket_name = "codedetect-uploads"  # Same as prod!

# terraform.tfvars
s3_bucket_name = "codedetect-uploads"
```

**Error:** S3 bucket names must be globally unique!

**Solution:** Use different names:
```hcl
# staging.tfvars
s3_bucket_name = "codedetect-staging-uploads"

# terraform.tfvars
s3_bucket_name = "codedetect-prod-uploads"
```

---

### ❌ Mistake 3: Forgetting to Destroy Staging

Staging runs 24/7 → Doubles your costs!

**Solution:** Set calendar reminder to destroy staging after testing.

---

## Advanced: Auto-Shutdown Staging

### Lambda Function to Stop Staging at Night

Save costs by auto-stopping staging EC2 instances at night:

```python
# lambda-stop-staging.py
import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')

    # Get all staging instances
    instances = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Environment', 'Values': ['staging']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )

    instance_ids = []
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])

    if instance_ids:
        ec2.stop_instances(InstanceIds=instance_ids)
        print(f'Stopped instances: {instance_ids}')

    return {'statusCode': 200}
```

**EventBridge Rule:** Run every day at 10 PM

---

## Summary

### What You Learned:

1. ✅ **Why staging matters**: Test changes without affecting production
2. ✅ **Terraform Workspaces**: Manage multiple environments with same code
3. ✅ **Cost optimization**: On-demand staging saves 88% vs always-on
4. ✅ **Safe workflow**: Always test in staging before production
5. ✅ **Git strategy**: Use branches for different environments

### Your New Workflow:

```
1. Make changes locally
2. Deploy to STAGING (isolated environment)
3. Test thoroughly
4. If works ✓ → Deploy to PRODUCTION
5. If breaks ✗ → Fix and repeat from step 2
6. Destroy staging to save costs
```

### Next Steps:

1. Create staging workspace
2. Create `staging.tfvars` file
3. Deploy staging environment
4. Test your next change in staging first!
5. Never deploy directly to production again

**Production server stays safe!** 🎯🛡️

---

## Quick Start Commands

```bash
# One-time setup
cd terraform
terraform workspace new staging
# Create staging.tfvars file (see above)

# Before testing changes
terraform workspace select staging
terraform apply -var-file="staging.tfvars"

# After testing
terraform destroy -var-file="staging.tfvars"
terraform workspace select default
```

That's it! Your production is now protected. 🚀
