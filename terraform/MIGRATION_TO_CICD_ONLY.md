# Migration to CI/CD Only Deployment

## Current Situation
- ✅ Infrastructure is working (Green environment active with 2 instances)
- ❌ Both local Terraform and GitHub Actions trying to manage same infrastructure
- ❌ State conflicts causing GitHub Actions failures

## Goal
Move to CI/CD-only deployment model for maintainability

---

## Step 1: Stop Running Terraform Locally

**From now on, DO NOT run these commands on your laptop:**
```bash
# ❌ NEVER RUN THESE ANYMORE
terraform apply
terraform plan
terraform destroy
```

**Why?** This prevents state conflicts with GitHub Actions.

**What if I need to test changes?**
- Use `terraform plan` locally (safe, read-only)
- Push to a `dev` branch first (we can set this up)
- Or use manual trigger in GitHub Actions UI

---

## Step 2: Let GitHub Actions Own the Infrastructure

**Current state in S3:**
```
active_environment = "green"
docker_tag = "v1.0"
```

**GitHub Actions will now be the ONLY thing that modifies this.**

---

## Step 3: How to Deploy Going Forward

### **For Automatic Deployments (Recommended):**

```bash
# Make code changes
# Edit backend/app.py or other files

# Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# GitHub Actions automatically:
# 1. Runs tests
# 2. Builds Docker image (auto-tagged: v20251124-abc1234)
# 3. Deploys to Blue environment (the inactive one)
# 4. Waits for health checks
# 5. Switches traffic to Blue
# 6. Monitors for errors
```

**That's it! No Terraform commands needed.**

---

### **For Manual Blue/Green Switch:**

If you want to manually control which environment to deploy to:

**Step 1:** Go to GitHub Actions UI
```
https://github.com/Ntnick-22/codeDetect/actions
```

**Step 2:** Click "CI/CD - Docker Build & Blue/Green Deploy"

**Step 3:** Click "Run workflow" button (top right)

**Step 4:** Fill in the form:
```
docker_tag: v1.2            (which Docker image to deploy)
deploy_environment: blue    (deploy to blue or green)
```

**Step 5:** Click "Run workflow" (green button)

**Step 6:** Watch the progress in real-time

---

## Step 4: Monitoring Deployments

### **Check Deployment Status:**

**In GitHub UI:**
```
https://github.com/Ntnick-22/codeDetect/actions
```
- Green checkmark ✅ = Success
- Red X ❌ = Failed
- Yellow circle ⏳ = In progress

**Check Application Health:**
```bash
# Option 1: Via ALB (always works)
curl http://codedetect-prod-alb-1746261995.eu-west-1.elb.amazonaws.com/api/health

# Option 2: Via domain (after DNS propagates)
curl https://codedetect.nt-nick.link/api/health
```

### **Check Which Environment is Active:**

**Via AWS Console:**
```
1. Go to EC2 → Auto Scaling Groups
2. Look for:
   - codedetect-prod-blue-asg
   - codedetect-prod-green-asg
3. Check "Desired Capacity"
   - Active environment: Desired = 2
   - Inactive environment: Desired = 0
```

**Via AWS CLI:**
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-blue-asg codedetect-prod-green-asg \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity]' \
  --output table
```

---

## Step 5: Rollback Process (If Deployment Fails)

### **Automatic Rollback:**
GitHub Actions includes health checks. If new deployment fails health checks, it will:
1. Report failure in GitHub Actions
2. Keep old environment active (no traffic switch)
3. You can manually switch back if needed

### **Manual Rollback:**

If you deployed Blue (v1.2) and it has issues, rollback to Green (v1.0):

**Option 1: Via GitHub Actions UI**
```
1. Go to GitHub Actions
2. Click "Run workflow"
3. Set:
   - deploy_environment: green
   - docker_tag: v1.0
4. Click "Run workflow"
```

**Option 2: Via Git Revert (Automatic)**
```bash
# Find the bad commit
git log --oneline

# Revert it
git revert abc1234
git push origin main

# GitHub Actions automatically deploys the reverted code
```

---

## Step 6: Understanding the Deployment Timeline

**What happens after `git push`:**

```
0:00 - Push to GitHub
0:01 - GitHub Actions triggered
0:02 - Running tests (Pylint, Bandit)
0:05 - Building Docker image
0:08 - Pushing to Docker Hub
0:10 - Terraform init
0:11 - Terraform plan
0:12 - Terraform apply (creates new ASG instances)
2:00 - EC2 instances booting (user data script running)
4:00 - Docker pulling images
6:00 - Docker containers starting
8:00 - Health checks passing
9:00 - Traffic switches to new environment
10:00 - Deployment complete ✅
```

**Total time: ~10 minutes**

---

## Step 7: Troubleshooting CI/CD Failures

### **Common Issues:**

**Issue 1: "Exit code 1" with no clear error**
**Cause:** State conflict or resource already exists
**Fix:** Check GitHub Actions logs for specific Terraform error

**Issue 2: Health checks failing**
**Cause:** Docker containers not starting
**Fix:** SSH into instance and check:
```bash
# Check Docker containers
docker ps

# Check logs
docker-compose logs

# Check if docker-compose.yml exists
ls -la /home/ec2-user/app/docker-compose.yml
```

**Issue 3: "Target.NotInUse"**
**Cause:** ALB not forwarding to target group
**Fix:** Check listener rules in loadbalancer.tf

---

## Step 8: Current State Summary

**What's working right now:**
- ✅ Green environment: 2 instances, healthy, serving traffic
- ✅ Application accessible via ALB URL
- ✅ Domain: codedetect.nt-nick.link (DNS + HTTPS enabled)
- ✅ EFS database shared across instances
- ✅ Docker image v1.0 running

**What needs fixing:**
- ⚠️ Stop running Terraform locally (causes CI/CD conflicts)
- ⚠️ Let GitHub Actions be the single source of truth

---

## Step 9: Best Practices Going Forward

### **DO:**
- ✅ Push code to GitHub, let CI/CD deploy
- ✅ Use GitHub Actions UI for manual deployments
- ✅ Monitor GitHub Actions logs
- ✅ Test in Blue before switching traffic
- ✅ Keep Docker images tagged with versions

### **DON'T:**
- ❌ Run `terraform apply` locally
- ❌ SSH into instances and manually edit files
- ❌ Push directly to main without testing
- ❌ Use `latest` tag for production deployments
- ❌ Skip health checks

---

## Step 10: Deployment Checklist

**Before Every Deployment:**
- [ ] Code changes committed to Git
- [ ] Tests passing locally
- [ ] Docker image builds successfully locally
- [ ] Ready to monitor deployment for 10 minutes

**After Every Deployment:**
- [ ] GitHub Actions shows green checkmark
- [ ] Health check returns HTTP 200
- [ ] Application works as expected
- [ ] Logs show no errors

---

## Emergency Contacts

**If deployment fails catastrophically:**

1. **Check GitHub Actions logs**
   - URL: https://github.com/Ntnick-22/codeDetect/actions

2. **Check AWS Console**
   - EC2 → Auto Scaling Groups
   - EC2 → Load Balancers → Target Groups
   - CloudWatch → Logs

3. **Rollback immediately**
   - Use GitHub Actions UI to switch back to previous environment

---

## Summary

**Old way (causing conflicts):**
```
You: terraform apply (locally)
GitHub: terraform apply (CI/CD)
Result: State conflicts 💥
```

**New way (clean and maintainable):**
```
You: git push
GitHub: Handles everything automatically ✅
Result: Reliable deployments 🎉
```

**Key takeaway:** Let GitHub Actions be the ONLY thing that runs Terraform. You focus on writing code and pushing to Git.
