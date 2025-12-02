# Staging Environment - Quick Start Guide

## 🎯 What This Does

**Before deploying to production** (your live website), test changes on a **temporary staging server** to avoid crashes!

```
❌ Old way: Change code → Deploy to production → 💥 Crash → Users affected!

✅ New way: Change code → Deploy to staging → Test → Works? → Deploy to production
```

---

## ⚡ Super Quick Start (3 Commands)

### Windows:
```bash
# 1. Deploy temporary staging server
deploy-staging.bat

# 2. Test your changes on staging URL
# (URL will be shown after deployment)

# 3. Destroy staging when done (save money!)
deploy-staging.bat destroy
```

### Mac/Linux:
```bash
# 1. Make script executable (first time only)
chmod +x deploy-staging.sh

# 2. Deploy temporary staging server
./deploy-staging.sh

# 3. Test your changes on staging URL
# (URL will be shown after deployment)

# 4. Destroy staging when done (save money!)
./deploy-staging.sh destroy
```

**That's it!** 3 commands to safely test before production.

---

## 📋 Complete Workflow

### Scenario: You made code changes and want to test them

#### Step 1: Deploy Staging
```bash
# Windows
deploy-staging.bat

# Mac/Linux
./deploy-staging.sh
```

**What happens:**
- Creates temporary staging environment (5-10 minutes)
- Gives you a staging URL like: `http://codedetect-staging-alb-XXX.amazonaws.com`
- Costs ~$0.50 for 3-hour testing session

#### Step 2: Deploy Your Changes to Staging

**Option A: Test new Docker image**
```bash
# Build Docker image with staging tag
docker build -t ntnick/codedetect:staging-test .
docker push ntnick/codedetect:staging-test

# Update staging to use new image
cd terraform
terraform workspace select staging

# Edit staging.tfvars: change docker_tag to "staging-test"
# Then apply:
terraform apply -var-file="staging.tfvars"
```

**Option B: SSH and deploy manually**
```bash
# Get staging EC2 IP
cd terraform
terraform workspace select staging
terraform output

# SSH to staging instance
ssh -i codedetect-key ec2-user@<STAGING-IP>

# On staging server:
cd /home/ec2-user/app
git pull origin main  # Or your feature branch
docker-compose down
docker-compose up -d
```

#### Step 3: Test Thoroughly

```bash
# Get staging URL
cd terraform
terraform workspace select staging
terraform output load_balancer_url

# Test all functionality:
curl http://staging-url/api/health
curl http://staging-url/api/info

# Open in browser and test manually
# Click all buttons, test all features!
```

#### Step 4: Decision Time

**If everything works ✅:**
```bash
# Deploy to production
git push origin main
# (Your CI/CD will deploy to production)

# Destroy staging
deploy-staging.bat destroy  # Windows
./deploy-staging.sh destroy  # Mac/Linux
```

**If something breaks ❌:**
```bash
# Fix the code
# Rebuild Docker image
# Redeploy to staging
# Test again

# Production is still safe and running!
```

---

## 💰 Cost Tracking

### Per Testing Session:
- **Duration:** 3 hours
- **Cost:** ~$0.50
- **Resources:** 2 EC2 instances + 1 ALB

### Monthly (if testing 2x per week):
- **Sessions:** 8 per month
- **Cost:** ~$4/month
- **Production:** Still only $26/month
- **Total:** $30/month

**Very affordable for safety!**

---

## 🎬 Real-World Examples

### Example 1: Testing New Feature

```bash
# 1. Created new "export" feature
# 2. Not sure if it works? Test on staging first!

deploy-staging.bat

# Wait for staging URL...
# http://codedetect-staging-alb-12345.eu-west-1.elb.amazonaws.com

# Deploy my changes to staging
cd terraform
terraform workspace select staging
# Update staging.tfvars: docker_tag = "staging-export-v1"
terraform apply -var-file="staging.tfvars"

# Test export feature on staging
curl http://staging-url/api/export
# Click export button in browser

# It works! ✅
# Deploy to production
git push origin main

# Clean up staging
deploy-staging.bat destroy
```

**Result:** New feature deployed safely, no production downtime!

---

### Example 2: Testing Infrastructure Change

```bash
# 1. Want to upgrade instance type from t3.micro to t3.small
# 2. Not sure if it will cause issues? Test on staging!

deploy-staging.bat

# Edit terraform/staging.tfvars
# instance_type = "t3.small"

cd terraform
terraform workspace select staging
terraform apply -var-file="staging.tfvars"

# Test if everything still works with new instance type
# Check application performance, memory usage, etc.

# It works! ✅
# Apply same change to production
terraform workspace select default
# Edit terraform.tfvars: instance_type = "t3.small"
terraform apply -var-file="terraform.tfvars"

# Clean up staging
deploy-staging.bat destroy
```

**Result:** Infrastructure upgraded safely!

---

### Example 3: Demonstrating to Client/Professor

```bash
# 1. Need to show working system for presentation
# 2. Don't want to risk production during demo

# Deploy staging for demo
deploy-staging.bat

# Get staging URL
# Use this URL for presentation

# After presentation
deploy-staging.bat destroy
```

**Result:** Safe demo environment, production unaffected!

---

## 🔧 Troubleshooting

### Problem: "staging workspace doesn't exist"

**Solution:**
```bash
cd terraform
terraform workspace new staging
deploy-staging.bat  # Try again
```

---

### Problem: "S3 bucket already exists"

**Cause:** S3 bucket name must be globally unique

**Solution:** Edit `terraform/staging.tfvars`
```hcl
# Change this line to something unique:
s3_bucket_name = "codedetect-staging-uploads-YOUR-NAME-2025"
```

---

### Problem: Script doesn't run on Mac/Linux

**Solution:**
```bash
# Make script executable
chmod +x deploy-staging.sh

# Run again
./deploy-staging.sh
```

---

### Problem: Terraform says "0 resources to add"

**Cause:** Staging already deployed

**Solution:** Check if it's already running
```bash
cd terraform
terraform workspace select staging
terraform output load_balancer_url

# If it shows URL, staging is already running!
```

---

### Problem: Can't access staging URL

**Wait 5 minutes:** Instances need time to boot and deploy application

**Check health:**
```bash
curl http://staging-url/api/health

# If it returns error, wait longer or check:
cd terraform
terraform workspace select staging
terraform output  # Check instance IPs
```

---

## ⚠️ Important Reminders

### ✅ DO:
- Deploy staging before deploying to production
- Test thoroughly on staging
- Destroy staging when done testing
- Use staging for demos and presentations
- Check which workspace you're in before `terraform apply`

### ❌ DON'T:
- Don't leave staging running 24/7 (expensive!)
- Don't put real user data in staging
- Don't deploy to production without testing on staging first
- Don't confuse staging and production URLs
- Don't forget to destroy staging after testing

---

## 🚀 Advanced: Automated Staging Workflow

### For GitHub Actions (Future Enhancement)

Create `.github/workflows/deploy-staging.yml`:

```yaml
name: Deploy to Staging

on:
  push:
    branches:
      - develop  # Staging branch

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Build and push Docker image
        run: |
          docker build -t ntnick/codedetect:staging-${{ github.sha }} .
          docker push ntnick/codedetect:staging-${{ github.sha }}

      # Deploy to staging EC2...
```

**Workflow:**
1. Push to `develop` branch → Auto-deploys to staging
2. Test on staging
3. Merge `develop` → `main` → Auto-deploys to production

---

## 📊 Staging vs Production Comparison

| Feature | Production | Staging |
|---------|-----------|---------|
| **Uptime** | 24/7 always on | On-demand (when testing) |
| **Cost** | $26/month | ~$0.50 per session |
| **Domain** | codedetect.com | ALB DNS only |
| **SSL** | ✅ HTTPS | ❌ HTTP only |
| **Database** | RDS PostgreSQL | SQLite (cost saving) |
| **Instances** | 2 (high availability) | 1 (testing only) |
| **Monitoring** | Detailed | Basic |
| **Purpose** | Serve real users | Test before production |

---

## 📝 Quick Reference

### Common Commands

```bash
# Deploy staging
deploy-staging.bat          # Windows
./deploy-staging.sh         # Mac/Linux

# Destroy staging
deploy-staging.bat destroy  # Windows
./deploy-staging.sh destroy # Mac/Linux

# Check if staging is running
cd terraform
terraform workspace select staging
terraform output load_balancer_url

# Switch between environments
terraform workspace select staging    # Staging
terraform workspace select default    # Production

# Get current environment
terraform workspace show
```

---

## ✅ Pre-Deployment Checklist

Before deploying to production, verify on staging:

- [ ] All features work correctly
- [ ] No errors in application logs
- [ ] Database migrations successful
- [ ] API endpoints responding
- [ ] Frontend loads properly
- [ ] No security vulnerabilities
- [ ] Performance is acceptable
- [ ] Screenshots captured (if for demo)

**If all checks pass ✅ → Safe to deploy to production!**

---

## 🎯 Your New Deployment Workflow

### Every time you make changes:

```
1. Make code changes locally
2. Deploy staging: deploy-staging.bat
3. Deploy changes to staging
4. Test thoroughly on staging URL
5. If works ✓ → Deploy to production
   If breaks ✗ → Fix and go back to step 3
6. Destroy staging: deploy-staging.bat destroy
```

### Time Investment:
- **Deploying staging:** 10 minutes
- **Testing:** 15-30 minutes
- **Destroying staging:** 2 minutes
- **Total:** ~30-45 minutes per deployment

### Value:
- **Production uptime:** 99.9%
- **User complaints:** 0
- **Peace of mind:** Priceless! 😊

---

## 🆘 Getting Help

### If staging deployment fails:

1. **Check error message** in terminal
2. **Verify AWS credentials:** `aws configure list`
3. **Check Terraform version:** `terraform version` (need 1.0+)
4. **Review logs:**
   ```bash
   cd terraform
   terraform workspace select staging
   terraform plan -var-file="staging.tfvars"
   ```

### If still stuck:

- Check `STAGING-ENVIRONMENT-GUIDE.md` for detailed explanation
- Review `terraform/staging.tfvars` configuration
- Verify S3 bucket name is unique
- Make sure you have AWS permissions

---

## 🎓 Summary

**You now have:**
- ✅ One-command staging deployment
- ✅ Safe testing environment
- ✅ Cost-effective on-demand approach
- ✅ Protection for production server
- ✅ Professional deployment workflow

**What this means:**
- No more production crashes! 🛡️
- Test safely before going live ✅
- Save money with on-demand staging 💰
- Show demos without risk 🎬
- Deploy with confidence 🚀

**Next time you make changes:**

```bash
# Test first!
deploy-staging.bat

# Deploy to staging, test, then production
# Your users will thank you! 😊
```

---

**Remember:** 15 minutes of testing on staging saves hours of debugging production crashes!

Good luck! 🌟
