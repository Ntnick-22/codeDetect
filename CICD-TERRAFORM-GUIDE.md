# CI/CD and Terraform Infrastructure Guide

## Understanding Your Deployment Pipeline

### Current Setup Overview

Your project has **TWO SEPARATE deployment processes**:

1. **Application Deployment (CI/CD)** - GitHub Actions
   - Builds Docker images
   - Pushes to Docker Hub
   - Updates running containers on EC2

2. **Infrastructure Changes (Manual)** - Terraform
   - Creates/modifies AWS resources (EC2, ALB, VPC, etc.)
   - NOT automated via GitHub Actions
   - Must be run manually from your local machine

---

## How CI/CD Currently Works

### GitHub Actions Workflow (`.github/workflows/deploy.yml`)

**What it does:**
1. Triggers on push to `main` branch
2. Builds Docker image from `Dockerfile`
3. Pushes image to Docker Hub with tag (e.g., `blue-abc1234`)
4. SSHes into EC2 instance
5. Pulls new Docker image
6. Restarts containers with `docker-compose`

**What it DOES NOT do:**
- ❌ Does NOT run `terraform apply`
- ❌ Does NOT create/modify AWS infrastructure
- ❌ Does NOT change instance count, load balancers, etc.

---

## Terraform vs CI/CD Decision Matrix

| Change Type | Tool to Use | Automated? | Example |
|-------------|-------------|------------|---------|
| Application code changes | CI/CD (GitHub Actions) | ✅ Yes | Fix bug, add feature |
| Docker image updates | CI/CD (GitHub Actions) | ✅ Yes | Update Python version |
| Environment variables | CI/CD (GitHub Actions) | ✅ Yes | Change API keys |
| Instance count (scaling) | Terraform | ❌ No | 1 instance → 2 instances |
| Instance type changes | Terraform | ❌ No | t3.micro → t3.small |
| Add new AWS resources | Terraform | ❌ No | Add RDS database |
| Security group changes | Terraform | ❌ No | Open new port |
| Load balancer config | Terraform | ❌ No | Add HTTPS listener |
| VPC/networking changes | Terraform | ❌ No | Add subnet |

---

## Why Terraform Changes Are Manual

### Reasons:

1. **Safety**: Infrastructure changes can cause downtime if not carefully reviewed
2. **Cost Control**: Prevents accidental resource creation that increases costs
3. **State Management**: Terraform state must be carefully managed
4. **Approval Required**: Infrastructure changes should be reviewed before applying

### Best Practices:

- Always run `terraform plan` before `terraform apply`
- Review changes in detail
- Have rollback plan ready
- Apply during low-traffic periods
- Document all changes

---

## Step-by-Step: Pushing Terraform Changes to GitHub

### Scenario: You modified `loadbalancer.tf` for demo mode

### Step 1: Check What Changed

```bash
# See what files you modified
git status

# See the actual changes
git diff terraform/loadbalancer.tf
```

### Step 2: Decide on Branching Strategy

#### Option A: Feature Branch (RECOMMENDED)

**Use when:**
- Testing infrastructure changes
- Want to review before merging to main
- Collaborating with team

```bash
# Create and switch to new branch
git checkout -b demo/ha-presentation

# Add your changes
git add terraform/loadbalancer.tf

# Commit with descriptive message
git commit -m "Configure demo mode: 2 instances per environment

Changes:
- Blue ASG: min=2, max=4, desired=2
- Green ASG: min=2, max=4, desired=2
- Purpose: Demonstrate high availability for presentation
- Will revert after screenshots captured

Note: Requires manual terraform apply (not automated via CI/CD)"

# Push to GitHub
git push origin demo/ha-presentation

# Create Pull Request on GitHub for review
```

**Benefits:**
- Code is backed up to GitHub
- Can review changes before merging
- CI/CD will NOT run (different branch)
- Can merge to main later

#### Option B: Direct to Main (Use with Caution)

**Use when:**
- You're the only developer
- Changes are already tested
- Want to keep simple linear history

```bash
# Add changes
git add terraform/loadbalancer.tf

# Commit
git commit -m "Configure demo mode for HA presentation [terraform-only]"

# Push to main
git push origin main
```

**Note:** This WILL trigger CI/CD, but CI/CD only deploys application code, not infrastructure.

### Step 3: Apply Terraform Changes Manually

**GitHub doesn't know about these changes yet!** You must apply them:

```bash
# Navigate to terraform directory
cd terraform

# Review changes
terraform plan

# Apply infrastructure changes
terraform apply
```

---

## Handling CI/CD While Testing Infrastructure

### Problem: You push code to GitHub, but don't want CI/CD to deploy yet

### Solution 1: Use Branch Protection

Push to a feature branch instead of `main`:

```bash
git checkout -b infra/demo-setup
git add terraform/loadbalancer.tf
git commit -m "Infrastructure: demo mode configuration"
git push origin infra/demo-setup
```

CI/CD won't run because it only triggers on `main` branch.

### Solution 2: Skip CI/CD with Commit Message

Some GitHub Actions can be configured to skip on certain commit messages:

```bash
git commit -m "[skip ci] Configure demo infrastructure

This is infrastructure-only change requiring manual terraform apply"
```

**Check your `.github/workflows/deploy.yml`** to see if this is configured:

```yaml
name: Deploy CodeDetect

on:
  push:
    branches:
      - main
    # Skip if commit message contains [skip ci]
    paths-ignore:
      - '**.md'
      - 'terraform/**'  # Skip CI/CD if only Terraform changed
```

### Solution 3: Temporarily Disable Workflow

**Via GitHub UI:**
1. Go to repository on GitHub
2. Navigate to **Actions** tab
3. Select your workflow
4. Click **"..."** (three dots) → **Disable workflow**
5. Push your changes
6. Re-enable workflow after

---

## Recommended Workflow for Infrastructure Changes

### Full Process (Best Practice)

```bash
# 1. CREATE FEATURE BRANCH
git checkout -b infra/demo-ha-setup
git add terraform/loadbalancer.tf
git commit -m "Infra: Configure 2 instances per environment for demo"
git push origin infra/demo-ha-setup

# 2. APPLY TERRAFORM CHANGES LOCALLY
cd terraform
terraform plan
terraform apply

# 3. TEST INFRASTRUCTURE
# - Verify 4 instances running
# - Test load balancing
# - Test failover
# - Capture screenshots

# 4. REVERT TERRAFORM CHANGES (after demo)
# Edit loadbalancer.tf back to 1 instance
terraform plan
terraform apply

# 5. COMMIT REVERT
git add terraform/loadbalancer.tf
git commit -m "Infra: Revert to production config (1 instance per env)"
git push origin infra/demo-ha-setup

# 6. MERGE TO MAIN (optional)
# Create PR on GitHub and merge
# OR delete branch if changes were temporary:
git checkout main
git branch -D infra/demo-ha-setup
git push origin --delete infra/demo-ha-setup
```

---

## Understanding Terraform State

### What is Terraform State?

`terraform.tfstate` file tracks what AWS resources Terraform created.

**IMPORTANT:**
- State file must match actual AWS infrastructure
- If state file is lost, Terraform can't manage resources
- State file contains sensitive information (passwords, IPs)

### Where is Your State Stored?

Check `terraform/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "codedetect-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "eu-west-1"
  }
}
```

**Your state is stored in S3** - Good! This means:
- ✅ State persists even if local machine dies
- ✅ Can run Terraform from different machines
- ✅ Team members can collaborate
- ⚠️ Must have AWS credentials to access state

### Checking State

```bash
# List all resources in state
terraform state list

# Show details of specific resource
terraform state show aws_autoscaling_group.blue

# Refresh state from AWS (sync state with reality)
terraform refresh
```

---

## Common Scenarios

### Scenario 1: "I changed Terraform code but nothing happened!"

**Cause:** You committed to GitHub but didn't run `terraform apply`

**Solution:**
```bash
cd terraform
terraform plan   # See what will change
terraform apply  # Actually make the changes
```

---

### Scenario 2: "CI/CD deployed but my infrastructure change didn't apply"

**Cause:** CI/CD doesn't run Terraform, only application deployment

**Solution:**
- Infrastructure changes require manual `terraform apply`
- Consider automating Terraform with Terraform Cloud or GitHub Actions in future

---

### Scenario 3: "I want to test infrastructure changes without affecting production"

**Solution:**
1. Create separate environment:

```hcl
# terraform/terraform.tfvars
environment = "staging"  # Instead of "prod"
```

2. Apply to staging:
```bash
terraform workspace new staging
terraform apply
```

3. Test in staging
4. Apply to production when ready

---

### Scenario 4: "I pushed to main and CI/CD is deploying, but I'm not ready!"

**Solution:**
1. Go to GitHub → Actions tab
2. Find the running workflow
3. Click **"Cancel workflow run"**
4. Fix your code
5. Push again when ready

---

## Automating Terraform with GitHub Actions (Future)

If you want to automate infrastructure deployment in the future:

### Example Workflow (`.github/workflows/terraform.yml`)

```yaml
name: Terraform Infrastructure

on:
  push:
    branches:
      - main
    paths:
      - 'terraform/**'
  workflow_dispatch:  # Manual trigger

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-1

      - name: Terraform Init
        run: terraform init
        working-directory: terraform

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: terraform

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
        working-directory: terraform
```

**Required Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**⚠️ Warning:** Auto-applying Terraform can be dangerous! Consider requiring manual approval:

```yaml
      - name: Terraform Apply
        if: github.event_name == 'workflow_dispatch'  # Only on manual trigger
        run: terraform apply -auto-approve tfplan
```

---

## Quick Reference Commands

### Git Commands

```bash
# Check status
git status

# See changes
git diff

# Create branch
git checkout -b branch-name

# Commit changes
git add file.tf
git commit -m "message"

# Push to GitHub
git push origin branch-name

# Switch branches
git checkout main

# Delete branch
git branch -D branch-name
```

### Terraform Commands

```bash
# Initialize
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy everything (careful!)
terraform destroy

# List resources
terraform state list

# Show outputs
terraform output

# Format code
terraform fmt

# Validate syntax
terraform validate
```

---

## Best Practices Summary

### ✅ DO:

1. **Always run `terraform plan` before `terraform apply`**
2. **Commit Terraform changes to Git** (for history/backup)
3. **Use feature branches for testing**
4. **Document why you made infrastructure changes**
5. **Revert temporary changes** (like demo mode)
6. **Keep state file in S3** (already done)
7. **Review changes carefully**

### ❌ DON'T:

1. **Don't run `terraform apply` without reviewing plan**
2. **Don't commit `terraform.tfstate` to Git** (use S3 backend)
3. **Don't commit secrets** (`.env`, AWS keys)
4. **Don't apply Terraform in production without testing**
5. **Don't lose your state file**
6. **Don't run Terraform from multiple terminals simultaneously**

---

## Your Demo Checklist

- [ ] Modified `loadbalancer.tf` for demo mode
- [ ] Committed changes to Git (feature branch or main)
- [ ] Pushed to GitHub for backup
- [ ] Ran `terraform plan` to review changes
- [ ] Ran `terraform apply` to deploy 4 instances
- [ ] Verified infrastructure in AWS Console
- [ ] Took demo screenshots
- [ ] Reverted `loadbalancer.tf` to production config
- [ ] Ran `terraform apply` to scale back down
- [ ] Committed revert to Git
- [ ] Pushed final state to GitHub

---

## Need Help?

### Common Issues:

**"Terraform command not found"**
```bash
# Install Terraform
# macOS:
brew install terraform

# Windows:
# Download from https://www.terraform.io/downloads
```

**"Error: No valid credential sources"**
```bash
# Configure AWS credentials
aws configure

# Or use environment variables:
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

**"Error: State file locked"**
```bash
# Someone else is running Terraform, or previous run crashed
# Wait 5 minutes, or force unlock (careful!):
terraform force-unlock <lock-id>
```

**"Git push rejected"**
```bash
# Pull latest changes first
git pull origin main

# Then push
git push origin main
```

---

## Summary

**Key Takeaways:**

1. **CI/CD** (GitHub Actions) = Application deployment only
2. **Terraform** = Infrastructure changes, must be run manually
3. **Always** commit infrastructure changes to Git for backup
4. **Pushing to GitHub ≠ Applying changes** (must run `terraform apply`)
5. **Use feature branches** for testing infrastructure changes
6. **Review carefully** before applying infrastructure changes

Your current task:
1. ✅ Code already modified (`loadbalancer.tf`)
2. 📝 Commit and push to GitHub (use feature branch)
3. 🚀 Run `terraform apply` manually
4. 📸 Take demo screenshots
5. ⏮️ Revert and scale back down
6. ✅ Push reverted code

Good luck! 🎯
