# Start Staging Environment - Simple Steps

## What We're Doing:
Creating a **temporary test server** where you can safely test changes before deploying to production.

---

## Step 1: Create Staging Workspace (One-Time Setup)

Open Git Bash and run:

```bash
cd C:/Users/kyaws/codeDetect/terraform

# Create staging workspace
terraform workspace new staging

# Verify it was created
terraform workspace list
# You should see:
#   default
# * staging  ← You're here now
```

**Expected output:**
```
Created and switched to workspace "staging"!
```

---

## Step 2: Verify Staging Configuration

Check that `staging.tfvars` exists and is configured:

```bash
# Check if file exists
ls staging.tfvars

# View the config
cat staging.tfvars | grep -E "environment|docker_tag|s3_bucket"
```

**Should show:**
```
environment = "staging"
docker_tag = "staging-latest"
s3_bucket_name = "codedetect-staging-uploads-2025"
```

---

## Step 3: Initialize Terraform (If Needed)

```bash
# Make sure Terraform is initialized
terraform init
```

---

## Step 4: Deploy Staging Environment

```bash
# Preview what will be created
terraform plan -var-file="staging.tfvars"

# IMPORTANT: Check the plan shows:
# Plan: X to add, 0 to change, 0 to destroy
# This means NEW resources, not modifying production!
```

**If everything looks good, deploy:**

```bash
terraform apply -var-file="staging.tfvars"

# Type: yes

# Wait 5-10 minutes...
```

---

## Step 5: Get Staging URL

```bash
# Get the staging load balancer URL
terraform output load_balancer_url

# Example output:
# http://codedetect-staging-alb-123456789.eu-west-1.elb.amazonaws.com
```

**Save this URL!** This is your staging server.

---

## Step 6: Wait for Instances to Be Ready

```bash
# Wait 5-10 minutes for:
# - EC2 instances to boot
# - Docker to install
# - Application to deploy

# Check status
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=staging" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table
```

---

## Step 7: Test Staging

```bash
# Test health endpoint
curl http://<STAGING-URL>/api/health

# Expected: {"status":"healthy"}

# Test info endpoint
curl http://<STAGING-URL>/api/info

# Open in browser
start http://<STAGING-URL>
```

---

## Step 8: Deploy Your Changes to Staging

Now you can safely test changes on staging!

### Option A: Test New Docker Image

```bash
# 1. Build Docker image with staging tag
docker build -t nyeinthunaing/codedetect:staging-test .
docker push nyeinthunaing/codedetect:staging-test

# 2. Update staging to use new image
cd terraform
terraform workspace select staging

# 3. Edit staging.tfvars
# Change: docker_tag = "staging-test"

# 4. Apply changes
terraform apply -var-file="staging.tfvars"

# 5. Test on staging URL
```

### Option B: SSH and Update Manually

```bash
# Get staging instance IP
terraform workspace select staging
terraform output

# SSH to staging
ssh -i codedetect-key ec2-user@<STAGING-IP>

# On staging server:
cd /home/ec2-user/app
git pull origin main  # Or your feature branch
docker-compose down
docker-compose up -d

# Test changes
curl localhost/api/info
```

---

## Step 9: When Done Testing

**IMPORTANT:** Destroy staging to save costs!

```bash
cd terraform
terraform workspace select staging

# Destroy staging infrastructure
terraform destroy -var-file="staging.tfvars"

# Type: yes

# Switch back to production
terraform workspace select default
```

**This saves ~$0.15/hour** by not running staging 24/7.

---

## Quick Reference Commands

```bash
# DEPLOY STAGING
cd terraform
terraform workspace select staging
terraform apply -var-file="staging.tfvars"

# GET STAGING URL
terraform output load_balancer_url

# DESTROY STAGING (when done)
terraform destroy -var-file="staging.tfvars"
terraform workspace select default

# CHECK CURRENT WORKSPACE
terraform workspace show
```

---

## Using the Automated Scripts

Even easier - use the scripts!

### Windows:
```bash
# Deploy staging
./deploy-staging.bat

# Destroy staging
./deploy-staging.bat destroy
```

### Mac/Linux:
```bash
# Make executable (first time)
chmod +x deploy-staging.sh

# Deploy staging
./deploy-staging.sh

# Destroy staging
./deploy-staging.sh destroy
```

---

## Troubleshooting

### "Workspace staging already exists"
```bash
# Just switch to it
terraform workspace select staging
```

### "S3 bucket already exists"
```bash
# Edit staging.tfvars
# Change s3_bucket_name to something unique:
s3_bucket_name = "codedetect-staging-YOUR-NAME-2025"
```

### "Can't access staging URL"
```bash
# Wait 10 minutes for instances to fully boot
# Check if instances are running:
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=staging" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]'
```

### "Still seeing old version on staging"
```bash
# SSH to staging instance
ssh -i codedetect-key ec2-user@<STAGING-IP>

# Force update
cd /home/ec2-user/app
docker-compose down
docker rmi $(docker images -q)
docker pull nyeinthunaing/codedetect:staging-latest
docker-compose up -d
```

---

## Your New Workflow

### Every time you make changes:

```
1. Make code changes locally
   ↓
2. Deploy staging: ./deploy-staging.bat
   ↓
3. Test changes on staging URL
   ↓
4. If works ✓ → Deploy to production
   If breaks ✗ → Fix and retry step 3
   ↓
5. Destroy staging: ./deploy-staging.bat destroy
```

---

## Cost Reminder

- **Staging running:** ~$0.15/hour
- **Staging destroyed:** $0.00/hour
- **Always destroy when done testing!**

---

## Next Steps

1. Create staging workspace (Step 1)
2. Deploy staging (Step 4)
3. Get staging URL (Step 5)
4. Test it works (Step 7)
5. Try deploying a change (Step 8)
6. Destroy staging (Step 9)

**Ready to start?** Run:
```bash
cd C:/Users/kyaws/codeDetect/terraform
terraform workspace new staging
```

Let's get your staging environment running! 🚀
