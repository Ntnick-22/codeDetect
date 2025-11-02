# How to Update GitHub Secrets After Terraform Rebuild

## The Problem

When you run `terraform destroy` and `terraform apply`, you get a **NEW Elastic IP**.

Your GitHub Actions CI/CD uses secrets that contain the OLD IP address, so deployment fails with:
```
ssh: connect to host *** port 22: Connection timed out
```

## The Solution

After every `terraform apply`, update your GitHub secrets.

---

## Method 1: Automatic (Using GitHub CLI)

### Step 1: Install GitHub CLI (One-time)

**Windows:**
```powershell
winget install GitHub.cli
```

**Mac:**
```bash
brew install gh
```

**Linux:**
```bash
sudo apt install gh
```

### Step 2: Login to GitHub (One-time)
```bash
gh auth login
# Follow prompts, choose HTTPS, authenticate via browser
```

### Step 3: Run the Update Script
```bash
cd terraform
chmod +x update_github_secrets.sh  # Make executable (Linux/Mac)
./update_github_secrets.sh          # Run script

# Windows Git Bash:
bash update_github_secrets.sh
```

**Done!** Your secrets are updated automatically.

---

## Method 2: Manual (Via GitHub Website)

### Step 1: Get Current Values

In your terminal:
```bash
cd terraform
terraform output ec2_public_ip
cat codedetect-key
```

Copy these values.

### Step 2: Update GitHub Secrets

1. Go to: https://github.com/Ntnick-22/codeDetect/settings/secrets/actions
2. Update these 3 secrets:

   **EC2_HOST:**
   ```
   54.77.153.228  # (your current IP from terraform output)
   ```

   **EC2_USER:**
   ```
   ec2-user
   ```

   **SSH_PRIVATE_KEY:**
   ```
   -----BEGIN OPENSSH PRIVATE KEY-----
   (paste entire contents of codedetect-key file)
   -----END OPENSSH PRIVATE KEY-----
   ```

3. Click "Update secret" for each one

**Done!** CI/CD will work on next push.

---

## When to Update Secrets

### ✅ **UPDATE NEEDED** (IP Changed):
```bash
terraform destroy   # Destroyed everything
terraform apply     # Created new infrastructure
                    # → NEW Elastic IP assigned
                    # → UPDATE SECRETS!
```

### ❌ **NO UPDATE NEEDED** (IP Same):
```bash
# Just code changes
git push

# EC2 restart
aws ec2 reboot-instances --instance-ids i-xxx

# Terraform refresh
terraform plan
terraform apply  # (no changes to EIP resource)
```

---

## How to Check If Secrets Are Correct

### Test 1: Check Current IP
```bash
cd terraform
terraform output ec2_public_ip
# Should show: 54.77.153.228
```

### Test 2: Check GitHub Secret (Can't see value, but can test)
```bash
# Trigger a deployment manually
git commit --allow-empty -m "Test deployment"
git push

# Check GitHub Actions:
# https://github.com/Ntnick-22/codeDetect/actions
```

If it works → Secrets are correct ✅
If SSH timeout → Secrets are outdated ❌

---

## Future Improvement: Avoid This Problem

To keep the **SAME IP** forever, even after destroy/apply:

**Option 1: Import Existing EIP** (Advanced)
```hcl
# In terraform/ec2.tf, change:
resource "aws_eip" "main" {
  domain = "vpc"
}

# To:
resource "aws_eip" "main" {
  domain = "vpc"

  lifecycle {
    prevent_destroy = true  # Don't destroy EIP
  }
}
```

**Option 2: Manual EIP Management**
1. Create EIP manually in AWS Console (one time)
2. Never destroy it
3. Use `terraform import` to manage it

**For now:** Just update secrets after each rebuild. It's simple and works!

---

## Quick Reference

```bash
# Workflow after terraform destroy/apply:
cd terraform
terraform apply                       # Build infrastructure
./update_github_secrets.sh           # Update GitHub secrets
git push                              # Test deployment
```

That's it!
