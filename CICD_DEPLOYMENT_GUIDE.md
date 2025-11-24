# CI/CD-Only Deployment Guide

**IMPORTANT: We are now using CI/CD-ONLY deployment model**

This means:
- ✅ All deployments happen via GitHub Actions (automatic)
- ❌ No more `terraform apply` on your laptop
- ✅ Infrastructure managed by CI/CD only
- ✅ You just push code, GitHub handles the rest

---

## Current Infrastructure Status

**Active Environment:** Green (2 instances, healthy)
**Inactive Environment:** Blue (0 instances)
**Application URL:** https://codedetect.nt-nick.link
**ALB URL:** http://codedetect-prod-alb-1746261995.eu-west-1.elb.amazonaws.com

---

## How to Deploy (Automatic)

### **Method 1: Automatic Deployment on Push (Recommended)**

Every time you push to `main`, GitHub Actions automatically:

```bash
# 1. Make your code changes
# Edit files: backend/app.py, etc.

# 2. Commit and push
git add .
git commit -m "Add new feature: user dashboard"
git push origin main

# 3. GitHub Actions automatically:
#    - Runs tests (Pylint, Bandit)
#    - Builds Docker image (auto-tag: v20251124-abc1234)
#    - Pushes to Docker Hub
#    - Deploys to inactive environment (Blue)
#    - Runs health checks
#    - Switches traffic to new environment
#    - Monitors for errors

# 4. Check deployment progress:
# Visit: https://github.com/Ntnick-22/codeDetect/actions
```

**Timeline:**
- 0:00 - Push to GitHub
- 0:02 - Tests running
- 0:05 - Docker building
- 2:00 - EC2 instances launching
- 8:00 - Health checks passing
- 10:00 - Deployment complete ✅

---

### **Method 2: Manual Blue/Green Switch**

If you want to manually control deployment:

**Step 1:** Go to GitHub Actions
```
https://github.com/Ntnick-22/codeDetect/actions
```

**Step 2:** Click "CI/CD - Docker Build & Blue/Green Deploy"

**Step 3:** Click "Run workflow" (top right)

**Step 4:** Configure:
```
Branch: main
docker_tag: v1.0 (or any tag you want to deploy)
deploy_environment: blue (or green)
```

**Step 5:** Click green "Run workflow" button

**Step 6:** Watch real-time progress in GitHub Actions UI

---

## Monitoring Deployments

### **Check Deployment Status**

**GitHub Actions UI:**
```
https://github.com/Ntnick-22/codeDetect/actions
```
- ✅ Green checkmark = Success
- ❌ Red X = Failed (check logs)
- ⏳ Yellow circle = In progress

**Application Health:**
```bash
# Check if app is responding
curl https://codedetect.nt-nick.link/api/health

# Expected response:
{"status":"ok","timestamp":"2025-11-24T..."}
```

**Which Environment is Active:**
```bash
# Run this script (see below)
./check-status.sh
```

---

## Helper Scripts (Read-Only)

I've created helper scripts to CHECK status without modifying infrastructure:

### **check-status.sh** - See current deployment status
```bash
./check-status.sh
```
Shows:
- Which environment is active (Blue or Green)
- Number of healthy instances
- Current Docker tag/version
- Application health status

### **check-logs.sh** - View instance logs
```bash
./check-logs.sh blue   # Check Blue environment logs
./check-logs.sh green  # Check Green environment logs
```

**IMPORTANT:** These scripts are READ-ONLY. They NEVER modify infrastructure.

---

## Rollback Process

### **If Deployment Fails:**

**Option 1: Revert Git Commit (Automatic)**
```bash
# Find the bad commit
git log --oneline

# Revert it
git revert abc1234

# Push (triggers automatic rollback deployment)
git push origin main
```

**Option 2: Manual Switch via GitHub UI**
```
1. Go to: https://github.com/Ntnick-22/codeDetect/actions
2. Click "Run workflow"
3. Set:
   - deploy_environment: green (switch back to old environment)
   - docker_tag: v1.0 (old working version)
4. Click "Run workflow"
```

**Option 3: Emergency Local Rollback (ONLY IN EMERGENCY)**
```bash
# ⚠️ USE ONLY IF GITHUB IS DOWN OR EMERGENCY
cd terraform
terraform apply -var="active_environment=green" -var="docker_tag=v1.0"
```

---

## What NOT to Do

### ❌ **DON'T run these commands anymore:**
```bash
# ❌ NEVER RUN ON YOUR LAPTOP
terraform apply
terraform plan -out=tfplan && terraform apply tfplan
./blue-green-deploy.sh

# These cause state conflicts with GitHub Actions!
```

### ✅ **DO run these (safe, read-only):**
```bash
# ✅ SAFE - Check status
./check-status.sh
terraform show    # View current state
terraform output  # See outputs

# ✅ SAFE - Check AWS directly
aws autoscaling describe-auto-scaling-groups
aws ec2 describe-instances
```

---

## Understanding Blue/Green Deployment

### **What is Blue/Green?**

Two identical production environments:
- **Blue Environment:** One version of your app
- **Green Environment:** Another version

**At any time, ONE is active (receiving traffic), ONE is inactive (idle)**

### **Deployment Flow:**

```
Current State:
  Green = Active (v1.0, 2 instances) ← Traffic goes here
  Blue = Inactive (0 instances)

Deploy v1.1:
1. GitHub Actions deploys v1.1 to Blue (inactive)
2. Blue spins up 2 new instances with v1.1
3. Health checks on Blue pass
4. Switch traffic: Blue becomes active
5. Green instances shut down

New State:
  Blue = Active (v1.1, 2 instances) ← Traffic goes here now
  Green = Inactive (0 instances)

Next deployment (v1.2):
  - Deploys to Green (since Blue is active)
  - Switches traffic to Green
  - And so on... alternating
```

### **Benefits:**
- **Zero downtime** - New version starts before old stops
- **Instant rollback** - Just switch back to old environment
- **Safe testing** - Test new version before switching traffic

---

## Troubleshooting

### **GitHub Actions Failed with "Exit Code 1"**

**Cause:** Usually Terraform state conflict or resource issue

**Fix:**
1. Check GitHub Actions logs for specific error
2. Look for Terraform error messages
3. Most common: "Resource already exists" or "State locked"

**Solution:**
- Wait 5 minutes for state lock to release
- Re-run the workflow manually

---

### **Health Checks Failing**

**Cause:** Docker containers not starting on EC2 instances

**Fix:**
1. SSH into instance:
```bash
# Get instance IP
aws ec2 describe-instances --filters 'Name=tag:aws:autoscaling:groupName,Values=codedetect-prod-blue-asg' --query 'Reservations[*].Instances[*].PublicIpAddress' --output text

# SSH in
ssh -i codedetect-key ec2-user@<IP>

# Check containers
docker ps
docker-compose logs
```

2. Check logs:
```bash
# On EC2 instance
tail -f /var/log/codedetect-deploy.log
```

---

### **"Can't Access Application"**

**Check:**
1. Is deployment complete? (Check GitHub Actions)
2. Is DNS working? `nslookup codedetect.nt-nick.link`
3. Is ALB healthy? Visit ALB URL directly
4. Are instances healthy? Run `./check-status.sh`

---

## Development Workflow

### **Daily Development:**

```bash
# Morning: Pull latest changes
git pull origin main

# Work on features
# Edit code, test locally with Docker

# Afternoon: Push changes
git add .
git commit -m "Feature: Add export to PDF"
git push origin main

# Watch deployment in GitHub Actions
# https://github.com/Ntnick-22/codeDetect/actions

# Verify deployment
curl https://codedetect.nt-nick.link/api/health
```

### **Testing Before Push:**

```bash
# Test Docker build locally
docker build -t codedetect-test .
docker run -p 5000:5000 codedetect-test

# Visit http://localhost:5000
# Test functionality

# If works, push to trigger deployment
git push origin main
```

---

## Cost Optimization

### **Current Costs (Approximate):**

**Active Environment (2 instances):**
- EC2 t3.small: $0.0208/hour × 2 = $0.0416/hour
- EBS 20GB: $0.08/month × 2 = $0.16/month
- **Monthly: ~$30 (active environment)**

**During Deployment (Brief):**
- Both environments active: $0.0832/hour
- Duration: ~10 minutes
- Cost per deployment: ~$0.014

**Other Costs:**
- ALB: ~$16/month
- EFS: ~$0.30/GB/month (depends on database size)
- S3: ~$0.023/GB/month (for uploads)
- **Total: ~$50-60/month**

**Savings Tips:**
- Inactive environment has 0 instances (no cost)
- Use t3.small instead of t3.medium (save $15/month)
- Delete old Docker images from Docker Hub

---

## Best Practices

### **✅ DO:**
- Push small, incremental changes
- Test locally with Docker before pushing
- Monitor GitHub Actions logs
- Check application health after deployment
- Keep commit messages clear: "Add feature: user export"

### **❌ DON'T:**
- Run `terraform apply` locally (causes conflicts)
- Push untested code to main
- Skip checking GitHub Actions status
- Force push (`git push -f`) to main
- Edit files directly on EC2 instances

---

## Emergency Procedures

### **If Production is Down:**

**Step 1: Check Status**
```bash
./check-status.sh
curl https://codedetect.nt-nick.link/api/health
```

**Step 2: Check GitHub Actions**
- Is deployment in progress?
- Did last deployment fail?

**Step 3: Rollback**
```bash
# Find last working commit
git log --oneline

# Revert to it
git revert <bad-commit-sha>
git push origin main

# Or manually switch environments in GitHub Actions UI
```

**Step 4: Investigate**
```bash
# SSH into instance
ssh -i codedetect-key ec2-user@<IP>

# Check logs
docker-compose logs -f
tail -f /var/log/codedetect-deploy.log
```

---

## Quick Reference

### **Commands You'll Use Daily:**

```bash
# Development
git pull origin main        # Get latest changes
git add .                   # Stage changes
git commit -m "message"     # Commit changes
git push origin main        # Deploy automatically

# Monitoring
./check-status.sh           # Check deployment status
curl https://codedetect.nt-nick.link/api/health  # Health check

# GitHub Actions
# Visit: https://github.com/Ntnick-22/codeDetect/actions
```

### **Commands You Should NEVER Use:**

```bash
# ❌ AVOID (causes state conflicts)
terraform apply
terraform plan -out=tfplan
./blue-green-deploy.sh manual
```

---

## Success Checklist

After every deployment, verify:

- [ ] GitHub Actions shows green checkmark
- [ ] Health endpoint returns HTTP 200
- [ ] Application loads in browser
- [ ] No errors in logs
- [ ] Both environments show correct state (one active, one inactive)

---

## Summary

**Old Way (Manual):**
```
1. Build Docker image locally
2. Push to Docker Hub
3. Run terraform apply
4. Wait and pray it works
5. Repeat for every deployment
```

**New Way (CI/CD Only):**
```
1. git push origin main
2. Done! ✅

GitHub Actions handles everything automatically.
```

**Benefits:**
- ⏱️ Saves 20 minutes per deployment
- 🔒 No state conflicts
- 📊 Complete audit trail
- 🤝 Team-friendly (anyone can deploy)
- 🚀 Consistent, reliable process

---

**Questions?**

Check GitHub Actions logs first:
https://github.com/Ntnick-22/codeDetect/actions

Or review this guide again.

**Remember:** Just push code. GitHub Actions does the rest!
