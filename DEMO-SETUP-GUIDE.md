# Demo Setup Guide - High Availability Infrastructure

## Overview
This guide will help you deploy 4 EC2 instances (2 Blue + 2 Green) to demonstrate:
- **Application Load Balancer** distributing traffic
- **Zero-downtime** failover when instance fails
- **High Availability** architecture

---

## Current Changes Made

### Modified File: `terraform/loadbalancer.tf`

**BLUE Auto Scaling Group** (Lines 301-308):
```hcl
# PRODUCTION (current): 1 instance per environment
# min_size         = var.active_environment == "blue" ? 1 : 0
# max_size         = var.active_environment == "blue" ? 2 : 0
# desired_capacity = var.active_environment == "blue" ? 1 : 0

# DEMO MODE (uncomment below for presentation - 2 instances per environment)
min_size         = var.active_environment == "blue" ? 2 : 0
max_size         = var.active_environment == "blue" ? 4 : 0
desired_capacity = var.active_environment == "blue" ? 2 : 0
```

**GREEN Auto Scaling Group** (Lines 372-379):
```hcl
# PRODUCTION (current): 1 instance per environment
# min_size         = var.active_environment == "green" ? 1 : 0
# max_size         = var.active_environment == "green" ? 2 : 0
# desired_capacity = var.active_environment == "green" ? 1 : 0

# DEMO MODE (uncomment below for presentation - 2 instances per environment)
min_size         = var.active_environment == "green" ? 2 : 0
max_size         = var.active_environment == "green" ? 4 : 0
desired_capacity = var.active_environment == "green" ? 2 : 0
```

---

## Step-by-Step Deployment Process

### Step 1: Push Changes to GitHub (WITHOUT triggering CI/CD)

**IMPORTANT**: We want to push code changes WITHOUT running GitHub Actions deployment yet!

#### Option A: Push to a Feature Branch (RECOMMENDED)

```bash
# Create a new branch for demo setup
git checkout -b demo/high-availability-test

# Add the modified file
git add terraform/loadbalancer.tf

# Commit with clear message
git commit -m "Configure demo mode: 2 instances per environment for HA presentation

- Uncommented demo mode settings in loadbalancer.tf
- Blue ASG: 2 instances (min:2, max:4, desired:2)
- Green ASG: 2 instances (min:2, max:4, desired:2)
- Total: 4 instances for failover demonstration
- Will revert after presentation screenshots"

# Push to GitHub (this will NOT trigger CI/CD on main)
git push origin demo/high-availability-test
```

#### Option B: Skip CI/CD with Commit Message Flag

```bash
# If your CI/CD is configured to skip on [skip ci] or [ci skip]
git add terraform/loadbalancer.tf
git commit -m "[skip ci] Configure demo mode for HA presentation"
git push origin main
```

#### Option C: Temporarily Disable GitHub Actions

1. Go to your GitHub repository
2. Navigate to: **Settings** → **Actions** → **General**
3. Under "Actions permissions", select **Disable actions**
4. Push your changes
5. Re-enable actions after manual deployment

---

### Step 2: Deploy Infrastructure Manually

Since CI/CD handles **application deployment** (Docker images), but NOT Terraform infrastructure changes, you need to apply Terraform manually.

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform (if needed)
terraform init

# IMPORTANT: Review what will change
terraform plan

# Expected output:
# ~ aws_autoscaling_group.blue
#   ~ desired_capacity: 1 -> 2
#   ~ min_size: 1 -> 2
#   ~ max_size: 2 -> 4
# ~ aws_autoscaling_group.green
#   ~ desired_capacity: 1 -> 2
#   ~ min_size: 1 -> 2
#   ~ max_size: 2 -> 4

# Apply the changes
terraform apply

# Type 'yes' when prompted
```

---

### Step 3: Wait for Instances to Launch (5-10 minutes)

AWS will now:
1. Launch 2 new Blue instances (if Blue is active)
2. Launch 2 new Green instances (if Green is active)
3. Wait for health checks to pass
4. Register them with ALB target groups

**Monitor Progress:**

```bash
# Watch instances being created
aws ec2 describe-instances \
  --filters "Name=tag:Application,Values=codedetect" \
           "Name=instance-state-name,Values=pending,running" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`DeploymentColor`].Value|[0]]' \
  --output table

# Watch target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw blue_target_group_arn) \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

**Or check via AWS Console:**
1. Go to **EC2 Dashboard** → **Instances**
2. Should see 4 instances: 2 Blue + 2 Green
3. Go to **EC2 Dashboard** → **Target Groups**
4. Check health status: Should show **2/2 healthy** for active environment

---

### Step 4: Verify Application is Working

```bash
# Get ALB DNS name
terraform output load_balancer_url

# Test the application
curl http://<ALB-DNS-NAME>/api/health

# Expected: HTTP 200 OK from both instances
```

Open in browser and refresh multiple times - you should see traffic distributed across instances.

---

## Taking Demo Screenshots

### Screenshot Checklist

#### 1. Infrastructure Overview
- [ ] **EC2 Dashboard** - All Instances view showing 4 running instances
- [ ] Filter by tag `Application=codedetect`
- [ ] Show instance IDs, states, and availability zones

#### 2. Auto Scaling Groups
- [ ] **EC2** → **Auto Scaling Groups**
- [ ] Show Blue ASG: Desired=2, Min=2, Max=4
- [ ] Show Green ASG: Desired=2, Min=2, Max=4
- [ ] Show instances running in both AZs (eu-west-1a, eu-west-1b)

#### 3. Target Groups (BEFORE Failure)
- [ ] **EC2** → **Target Groups** → Blue Target Group
- [ ] Show **2/2 targets healthy**
- [ ] Screenshot showing both instance IDs and health status

#### 4. Application Load Balancer
- [ ] **EC2** → **Load Balancers**
- [ ] Show ALB with DNS name
- [ ] Show listeners (HTTP:80)
- [ ] Show both target groups attached

#### 5. Application Working (BEFORE Failure)
- [ ] Open application in browser
- [ ] Navigate to `/api/info` to see instance ID
- [ ] Refresh multiple times to show load balancing
- [ ] Capture different instance IDs serving requests

#### 6. Simulate Instance Failure
- [ ] **EC2** → **Instances**
- [ ] Select ONE instance (note the instance ID)
- [ ] **Actions** → **Instance State** → **Terminate**
- [ ] Screenshot the termination confirmation

#### 7. Target Group During Failure
- [ ] **EC2** → **Target Groups** → Active Target Group
- [ ] Screenshot showing **1/2 healthy, 1 draining**
- [ ] Show the failing instance status changing

#### 8. Application Still Working (DURING Failure)
- [ ] Immediately refresh browser
- [ ] Application should STILL WORK (zero downtime!)
- [ ] Screenshot showing app is accessible
- [ ] Show `/api/info` now returning only healthy instance ID

#### 9. Auto Scaling Recovery (After ~5 minutes)
- [ ] Wait for ASG to detect failure
- [ ] New instance will be launched automatically
- [ ] Screenshot showing new instance being created
- [ ] Show target group returning to **2/2 healthy**

#### 10. Final State (Recovery Complete)
- [ ] **EC2 Dashboard** - 4 instances running again
- [ ] **Target Groups** - 2/2 healthy
- [ ] Application still working perfectly

---

## Architecture Diagram for Presentation

```
                    INTERNET
                        |
                        v
            [Application Load Balancer]
                        |
        +---------------+---------------+
        |                               |
    [Blue Target Group]          [Green Target Group]
        |                               |
    +---+---+                      +---+---+
    |       |                      |       |
[Blue-1] [Blue-2]              [Green-1] [Green-2]
 (AZ-a)   (AZ-b)                (AZ-a)   (AZ-b)

High Availability Features:
✓ Multi-AZ deployment
✓ Auto Scaling (2-4 instances)
✓ Health monitoring (30s interval)
✓ Automatic failover
✓ Zero downtime deployment
```

---

## Cleanup After Demo (IMPORTANT!)

### Step 1: Revert to Production Config

Edit `terraform/loadbalancer.tf`:

**BLUE Auto Scaling Group:**
```hcl
# PRODUCTION (current): 1 instance per environment
min_size         = var.active_environment == "blue" ? 1 : 0
max_size         = var.active_environment == "blue" ? 2 : 0
desired_capacity = var.active_environment == "blue" ? 1 : 0

# DEMO MODE (uncomment below for presentation - 2 instances per environment)
# min_size         = var.active_environment == "blue" ? 2 : 0
# max_size         = var.active_environment == "blue" ? 4 : 0
# desired_capacity = var.active_environment == "blue" ? 2 : 0
```

**GREEN Auto Scaling Group:**
```hcl
# PRODUCTION (current): 1 instance per environment
min_size         = var.active_environment == "green" ? 1 : 0
max_size         = var.active_environment == "green" ? 2 : 0
desired_capacity = var.active_environment == "green" ? 1 : 0

# DEMO MODE (uncomment below for presentation - 2 instances per environment)
# min_size         = var.active_environment == "green" ? 2 : 0
# max_size         = var.active_environment == "green" ? 4 : 0
# desired_capacity = var.active_environment == "green" ? 2 : 0
```

### Step 2: Apply Changes

```bash
cd terraform

# Review changes
terraform plan

# Apply to scale down to 1 instance per environment
terraform apply

# This will terminate extra instances and reduce costs
```

### Step 3: Push Reverted Code

```bash
# Add the reverted file
git add terraform/loadbalancer.tf

# Commit
git commit -m "Revert to production config: 1 instance per environment

- Demo complete, screenshots captured
- Scaling back down to minimize costs
- Blue/Green: 1 instance each (was 2)"

# Push
git push origin main
```

---

## Cost Estimation

### Demo Mode (4 instances for ~2 hours):
- **EC2 t3.micro**: 4 instances × $0.0104/hour × 2 hours = **$0.08**
- **ALB**: $0.0225/hour × 2 hours = **$0.05**
- **Data Transfer**: Negligible for testing
- **Total**: **~$0.15** for 2-hour demo

**Very affordable for a presentation!**

---

## Troubleshooting

### Issue: Instances stuck in "Pending" state

**Solution:**
```bash
# Check instance logs
aws ec2 get-console-output --instance-id <instance-id>

# Common causes:
# - User data script errors
# - EFS mount failures
# - Docker image pull issues
```

### Issue: Health checks failing

**Solution:**
```bash
# SSH into instance
ssh -i codedetect-key ec2-user@<instance-ip>

# Check application logs
cd /home/ec2-user/app
docker-compose logs -f

# Check if app is running on port 80
curl localhost/api/health
```

### Issue: Terraform apply hangs

**Solution:**
- AWS might be waiting for old instances to drain
- Check AWS Console → Auto Scaling Groups → Activity History
- Old instances should terminate after 30 seconds (deregistration_delay)

---

## Quick Reference Commands

```bash
# Get current instance count
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-blue-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

# Get ALB DNS
terraform output load_balancer_url

# Get target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw blue_target_group_arn)

# List all instances
aws ec2 describe-instances \
  --filters "Name=tag:Application,Values=codedetect" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table

# Manually trigger scaling (if needed)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name codedetect-prod-blue-asg \
  --desired-capacity 2
```

---

## Timeline for Demo Day

1. **1 hour before presentation**: Deploy 4 instances (`terraform apply`)
2. **Wait 10 minutes**: Verify all instances healthy
3. **Take screenshots**: Capture all "before" states
4. **During presentation**: Terminate one instance live
5. **Show zero downtime**: Refresh browser immediately
6. **After presentation**: Scale back down (`terraform apply` with reverted config)
7. **Push cleaned code**: Commit and push production config

---

## Key Points for Presentation

### What You're Demonstrating:

✅ **High Availability Architecture**
- Multiple instances across availability zones
- Automatic health monitoring
- Load balancing across instances

✅ **Zero-Downtime Deployment**
- Blue/Green deployment strategy
- Rolling updates with no service interruption

✅ **Automatic Failover**
- Instance failure detected within 30 seconds
- Traffic automatically routed to healthy instances
- Auto Scaling replaces failed instances

✅ **Infrastructure as Code**
- Entire infrastructure defined in Terraform
- Repeatable, version-controlled deployments
- Easy to scale up/down as needed

### What Happens When Instance Fails:

1. **T+0s**: Instance terminated
2. **T+5s**: ALB health check fails
3. **T+10s**: ALB stops sending traffic to failed instance
4. **T+30s**: Instance marked as "draining"
5. **T+60s**: Auto Scaling detects missing instance
6. **T+5min**: New instance launched and healthy
7. **T+6min**: Back to 2/2 healthy instances

**User Impact**: ZERO! Users see no downtime.

---

## Success Criteria

Before your presentation, verify:
- [ ] 4 instances running (2 Blue, 2 Green)
- [ ] All target groups showing healthy
- [ ] Application accessible via ALB DNS
- [ ] Can terminate instance without downtime
- [ ] Screenshots captured for all steps
- [ ] Know how to revert config after demo

---

## Questions You Might Get Asked

**Q: Why 4 instances for a small app?**
A: This is a demonstration of high availability architecture. In production, we run 1 instance per environment to minimize costs, but the infrastructure supports scaling to 4+ instances if traffic increases.

**Q: What happens during deployment?**
A: We use Blue/Green deployment. Deploy new version to Green environment, test it, then switch ALB to point to Green. Blue remains as rollback option.

**Q: How much does this cost?**
A: Production (2 instances total): ~$15/month. Demo (4 instances for 2 hours): ~$0.15. Very cost-effective!

**Q: Can this handle more traffic?**
A: Yes! Auto Scaling can add instances when CPU > 70%. Max capacity is 4 instances per environment (8 total). Can be increased by changing `max_size`.

**Q: What if entire availability zone fails?**
A: Instances are spread across 2 AZs (eu-west-1a and eu-west-1b). If one AZ fails, instances in the other AZ continue serving traffic.

---

Good luck with your presentation! 🚀
