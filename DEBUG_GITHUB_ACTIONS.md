# How to Debug GitHub Actions Errors

## Step-by-Step Guide to Find Error Details

### 1. Navigate to GitHub Actions
```
https://github.com/Ntnick-22/codeDetect/actions
```

### 2. Click the Failed Workflow Run
- Look for ❌ (red X) next to the latest run
- The commit message will be shown (e.g., "Fix deployment workflow order")
- Click on it

### 3. Identify Which Job Failed
You'll see 3 jobs:
```
✅ test                 (usually passes - runs Pylint, Bandit)
✅ build-docker         (usually passes - builds Docker image)
❌ deploy               (THIS is where it fails)
```

Click on the ❌ **deploy** job

### 4. Find the Failed Step
Within the deploy job, expand each step to find the red ❌:

**Likely failure points:**
- ❌ **Terraform Init** - Can't connect to S3 backend
- ❌ **Determine Target Environment** - Can't read Terraform state
- ❌ **Blue/Green Deployment** - Terraform plan/apply failed
- ❌ **Wait for Instances** - Instances not becoming healthy
- ❌ **Health Check** - Application not responding

### 5. Read the Error Message
Scroll through the logs and look for:

**Error indicators:**
```
Error: <error message>
❌ Terraform plan failed!
❌ Terraform apply failed!
exit status 1
```

**Common error patterns:**

#### Error Type 1: AWS Credentials Issue
```
Error: error configuring S3 Backend: no valid credential sources
Error: error configuring Terraform AWS Provider: no valid credentials
```
**Cause:** Missing or invalid AWS credentials in GitHub Secrets

#### Error Type 2: Terraform State Lock
```
Error: Error acquiring the state lock
Lock Info:
  ID: <some-uuid>
  Operation: OperationTypePlan
  Who: <user>@<host>
```
**Cause:** Another Terraform process is running (local or CI/CD conflict)

#### Error Type 3: Resource Already Exists
```
Error: Error creating <resource>: <resource> already exists
```
**Cause:** Local Terraform and GitHub Actions both trying to create same resource

#### Error Type 4: Terraform Output Not Found
```
Error: Output not found: active_environment
```
**Cause:** Terraform init not run before reading outputs

#### Error Type 5: Insufficient Permissions
```
Error: UnauthorizedOperation: You are not authorized to perform this operation
```
**Cause:** IAM user/role doesn't have required AWS permissions

---

## How to Copy Error Logs

### Option 1: Copy from Browser
1. Click the failed step in GitHub Actions
2. Scroll to the error
3. Click and drag to select the error text
4. Ctrl+C to copy
5. Paste here

### Option 2: Download Raw Logs
1. In the workflow run page (top right)
2. Click the ⋮ (three dots)
3. Click "Download log archive"
4. Extract the ZIP
5. Open the file for the failed step
6. Search for "Error:"

### Option 3: Use GitHub CLI (if installed)
```bash
# List recent runs
gh run list --repo Ntnick-22/codeDetect

# View specific run logs
gh run view <run-id> --log --repo Ntnick-22/codeDetect
```

---

## Quick Diagnosis Checklist

**If deployment fails at "Terraform Init":**
- [ ] Check if AWS_ACCESS_KEY_ID secret is set in GitHub
- [ ] Check if AWS_SECRET_ACCESS_KEY secret is set in GitHub
- [ ] Verify S3 bucket exists: `codedetect-terraform-state-772297676546`
- [ ] Check if GitHub Actions has permission to access S3

**If deployment fails at "Determine Target Environment":**
- [ ] Verify Terraform init completed successfully (previous step)
- [ ] Check if terraform output command works locally
- [ ] Ensure S3 backend is configured correctly

**If deployment fails at "Blue/Green Deployment" (Terraform plan/apply):**
- [ ] Check if local Terraform is running at the same time
- [ ] Look for "state lock" errors
- [ ] Check for "resource already exists" errors
- [ ] Verify docker_tag variable is passed correctly

**If deployment fails at "Wait for Instances":**
- [ ] Instances might not be launching (check ASG in AWS Console)
- [ ] User data script might be failing
- [ ] Docker image might not exist in Docker Hub
- [ ] Check EC2 instance logs via AWS Console

**If deployment fails at "Health Check":**
- [ ] Instances are running but app not responding
- [ ] Docker containers might not be starting
- [ ] Check security group allows traffic on port 80
- [ ] ALB target group health checks might be misconfigured

---

## Most Likely Issues for Our Setup

### Issue 1: State Conflict (Most Common)
**Symptom:** "Error acquiring state lock" or "exit code 1" at Terraform apply

**Why:** You ran `terraform apply` locally, then GitHub Actions also tries to apply

**Solution:**
```bash
# Option A: Wait 5 minutes for lock to expire naturally

# Option B: Force unlock (ONLY if you're sure no Terraform is running)
cd terraform
terraform force-unlock <LOCK_ID>

# Option C: Let GitHub Actions retry (it might succeed on retry)
```

### Issue 2: Terraform Init Before Output
**Symptom:** "Output not found" or terraform command fails

**Why:** Trying to read terraform output before running terraform init

**Status:** ✅ We fixed this in the latest commit

### Issue 3: Missing GitHub Secrets
**Symptom:** "no valid credential sources" or AWS authentication errors

**Check GitHub Secrets:**
```
https://github.com/Ntnick-22/codeDetect/settings/secrets/actions
```

**Required secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DOCKER_HUB_TOKEN`

### Issue 4: Concurrent Deployments
**Symptom:** Both environments trying to be active at once

**Why:** Local apply and GitHub Actions apply running simultaneously

**Solution:**
- Stop running `terraform apply` locally
- Let GitHub Actions be the only deployer
- Use `./check-status.sh` to monitor (read-only)

---

## What to Share for Help

To help you debug, I need to see the actual error. Please share:

### Minimum Info Needed:
1. **Which step failed?** (e.g., "Blue/Green Deployment")
2. **Error message** (the lines starting with "Error:")
3. **Exit code** (if shown)

### Full Debugging Info (Best):
Copy and paste the **last 50 lines** of the failed step. Usually contains:
- What command was running
- The error message
- The exit code
- Sometimes a stack trace

---

## Example of What to Look For

Good error report:
```
❌ Blue/Green Deployment failed

Logs:
=== BLUE/GREEN DEPLOYMENT ===
🐳 Docker Tag: v20251124-abc1234
🎯 Target Environment: blue

📋 Running Terraform plan...

Error: Error acquiring the state lock

Lock Info:
  ID: 12345678-1234-1234-1234-123456789abc
  Path: codedetect-terraform-state-772297676546/prod/terraform.tfstate
  Operation: OperationTypePlan
  Who: your-laptop@hostname
  Version: 1.6.0
  Created: 2025-11-24 16:54:00 UTC

Terraform acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and try
again. For most commands, you can disable locking with the "-lock=false"
flag, but this is not recommended.

exit code 1
```

From this we can see:
- **Problem:** State is locked
- **Locked by:** Your local laptop
- **When:** 16:54:00 UTC
- **Solution:** Wait or force unlock

---

## Quick Commands to Check Infrastructure

While debugging GitHub Actions, check current state:

```bash
# Check which environment is active
cd terraform
terraform output active_environment

# Check instance health
./check-status.sh

# Check if state is locked
terraform plan -var="active_environment=green"
# If it hangs, state is locked
# Press Ctrl+C to cancel

# Check recent AWS activity
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-blue-asg codedetect-prod-green-asg \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity]' \
  --output table
```

---

## Next Steps

1. **Go to GitHub Actions** and find the error
2. **Copy the error message** (last 50 lines of failed step)
3. **Paste it here** or screenshot it
4. I'll analyze and tell you exactly what's wrong and how to fix it

**GitHub Actions URL:**
https://github.com/Ntnick-22/codeDetect/actions

---

## Remember

**"Exit code 1"** just means "something failed"
- It doesn't tell us WHAT failed
- We need to see the actual error message ABOVE the "exit code 1" line
- The real error is usually 10-50 lines BEFORE the exit code

**Look for these keywords in the logs:**
- `Error:`
- `failed`
- `❌`
- Red colored text
- `panic:`
- `exception`
