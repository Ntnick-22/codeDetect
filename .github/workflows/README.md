# GitHub Actions CI/CD Setup

This directory contains GitHub Actions workflows for automated testing and deployment.

## 📋 Available Workflows

### Option 1: Simple SSH Deployment (ACTIVE)
**File**: `deploy.yml`

**What it does:**
1. Runs code quality checks (Pylint, Bandit, Radon)
2. Tests Docker build
3. SSHs into EC2
4. Pulls latest code from GitHub
5. Rebuilds and restarts Docker container
6. Runs health check

**Triggers:**
- Every push to `main` branch
- Manual trigger via GitHub Actions UI

---

### Option 2: ECR Docker Registry (DISABLED)
**File**: `deploy-ecr.yml`

**What it does:**
1. Runs code quality checks
2. Builds Docker image
3. Pushes to AWS ECR (Elastic Container Registry)
4. SSHs into EC2
5. Pulls image from ECR
6. Restarts container with new image
7. Runs health check

**Status:** Currently disabled (to enable, see instructions below)

---

## 🔐 Required GitHub Secrets

You need to set up these secrets in your GitHub repository:

### For Option 1 (Simple SSH):

1. **SSH_PRIVATE_KEY** - Your EC2 SSH private key
2. **EC2_HOST** - Your EC2 public IP address
3. **EC2_USER** - SSH username (usually `ec2-user`)

### For Option 2 (ECR Deployment) - Additional:

4. **AWS_ACCESS_KEY_ID** - AWS access key for ECR
5. **AWS_SECRET_ACCESS_KEY** - AWS secret key for ECR
6. **AWS_ACCOUNT_ID** - Your AWS account ID (12 digits)

---

## 📖 Step-by-Step Setup Guide

### Step 1: Add GitHub Secrets

1. **Go to your GitHub repository**
   - Navigate to: https://github.com/Ntnick-22/codeDetect

2. **Open Settings**
   - Click on "Settings" tab at the top

3. **Go to Secrets and Variables**
   - In left sidebar: Click "Secrets and variables" → "Actions"

4. **Add each secret**
   - Click "New repository secret"
   - Add the secrets listed below

---

### 🔑 Secret Values to Add

#### 1. SSH_PRIVATE_KEY

**Value:** Your EC2 SSH private key content

**How to get it:**
```bash
# On your local machine, read the private key:
cat C:\Users\kyaws\codeDetect\terraform\codedetect-key

# Copy the ENTIRE output, including:
# -----BEGIN OPENSSH PRIVATE KEY-----
# ... (all the key content) ...
# -----END OPENSSH PRIVATE KEY-----
```

**Important:**
- Copy the ENTIRE key including the BEGIN and END lines
- Include all line breaks
- Don't add any extra spaces or characters

---

#### 2. EC2_HOST

**Value:** Your EC2 public IP address

**Current value:** `108.128.137.219`

**How to get it:**
```bash
# From terraform directory:
terraform output ec2_public_ip

# Or check AWS console → EC2 → Instances
```

---

#### 3. EC2_USER

**Value:** `ec2-user`

**Note:** This is the default user for Amazon Linux 2 AMI

---

#### 4. AWS_ACCESS_KEY_ID (Only for Option 2)

**Value:** Your AWS access key ID

**How to get it:**
```bash
# If you have AWS CLI configured:
cat ~/.aws/credentials

# Look for: aws_access_key_id = AKIA...
```

**Or create new credentials:**
1. AWS Console → IAM → Users → Your user
2. Security credentials → Create access key
3. Select "Application running outside AWS"
4. Copy the Access Key ID

---

#### 5. AWS_SECRET_ACCESS_KEY (Only for Option 2)

**Value:** Your AWS secret access key

**Get it the same way as Access Key ID above**

**⚠️ Important:** Never commit this to git! Only add as GitHub Secret.

---

#### 6. AWS_ACCOUNT_ID (Only for Option 2)

**Value:** Your 12-digit AWS account ID

**How to get it:**
```bash
aws sts get-caller-identity --query Account --output text
```

**Or:** Top-right of AWS Console → Account dropdown

---

## 🚀 Testing the Workflow

### After adding secrets:

1. **Make a small change to any file**
   ```bash
   # Example: Add a comment to README
   echo "" >> README.md
   git add README.md
   git commit -m "Test CI/CD pipeline"
   git push origin main
   ```

2. **Watch the workflow run**
   - Go to: https://github.com/Ntnick-22/codeDetect/actions
   - You'll see the workflow running
   - Click on it to see live logs

3. **Check the results**
   - Green checkmark ✅ = Success!
   - Red X ❌ = Failed (click to see logs)

---

## 🔄 Switching Between Options

### Currently Active: Option 1 (Simple SSH)

**To disable Option 1:**
Edit `.github/workflows/deploy.yml`:
```yaml
# Change this:
on:
  push:
    branches:
      - main

# To this:
on: []
```

### To Enable Option 2 (ECR):

1. **First, set up ECR repository**
   - Use Terraform to create ECR (see terraform/ecr.tf)
   - Or create manually in AWS Console

2. **Add the 3 additional secrets** (listed above)

3. **Edit `.github/workflows/deploy-ecr.yml`:**
```yaml
# Change this:
on: []

# To this:
on:
  push:
    branches:
      - main
  workflow_dispatch:
```

4. **Commit and push**

---

## 🐛 Troubleshooting

### Workflow fails with "Permission denied (publickey)"
- Check SSH_PRIVATE_KEY is copied correctly
- Verify EC2_HOST is correct IP address
- Make sure key has proper BEGIN/END lines

### Workflow fails at "Health Check"
- App might not be starting properly
- Check docker-compose logs on EC2
- Verify port 5000 is open in security group

### ECR login fails (Option 2)
- Check AWS credentials are correct
- Verify IAM user has ECR permissions
- Make sure AWS_ACCOUNT_ID is correct

### Docker build fails
- Check Dockerfile syntax
- Verify all dependencies in requirements.txt
- Test build locally first: `docker build .`

---

## 📊 What Gets Deployed

Every successful deployment includes:
- ✅ Latest code from main branch
- ✅ Fresh Docker build
- ✅ Updated dependencies
- ✅ Database migrations (if any)
- ✅ S3 integration (with boto3)
- ✅ Environment variables from docker-compose.yml

---

## 🎯 Best Practices

1. **Always test locally first**
   ```bash
   docker-compose build
   docker-compose up
   # Test the app
   ```

2. **Check workflow logs**
   - Review test results before deployment
   - Check for security warnings from Bandit

3. **Use feature branches**
   ```bash
   git checkout -b feature/my-new-feature
   # Make changes
   git push origin feature/my-new-feature
   # Create Pull Request
   # Merge to main after review
   ```

4. **Monitor deployments**
   - Watch GitHub Actions for failures
   - Check application logs after deployment
   - Verify health endpoint: http://your-ip:5000/api/health

---

## 📞 Need Help?

If deployment fails:
1. Check GitHub Actions logs
2. SSH into EC2 and check docker logs:
   ```bash
   ssh -i codedetect-key ec2-user@108.128.137.219
   cd /home/ec2-user/app
   docker-compose logs -f
   ```
3. Verify all secrets are set correctly
4. Check AWS services are running (EC2, ECR if using Option 2)

---

## 🎉 Success Indicators

Deployment is successful when:
- ✅ All workflow steps are green
- ✅ Health check returns 200 OK
- ✅ Application is accessible at http://your-ip:5000
- ✅ Can upload and analyze files
- ✅ Files appear in S3 bucket

---

**Happy Deploying! 🚀**
