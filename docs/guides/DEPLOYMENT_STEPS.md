# RDS Deployment via GitHub Actions - Quick Guide

## You're Right! No Manual Terraform Apply Needed! ✅

Your GitHub Actions workflow automatically runs `terraform apply` when you push code!

---

## Deployment Flow

```
Your Laptop                    GitHub                      AWS
───────────                   ────────                   ─────

git add .
git commit -m "Add RDS"
git push origin main
                    ──────> GitHub Actions
                            triggers
                                │
                            ┌───┴────┐
                            │ Job 1: │
                            │  Test  │
                            └───┬────┘
                                │
                            ┌───┴────┐
                            │ Job 2: │
                            │ Build  │
                            │ Docker │
                            └───┬────┘
                                │
                            ┌───┴────────┐
                            │ Job 3:     │
                            │ Terraform  │───────> Creates RDS
                            │ Apply      │───────> Updates EC2
                            └────────────┘
```

---

## Steps to Deploy RDS

### ✅ Step 1: Add Database Password to GitHub Secrets

1. Go to: https://github.com/Ntnick-22/codeDetect/settings/secrets/actions
2. Click **"New repository secret"**
3. **Name:** `DB_PASSWORD`
4. **Value:** Your secure password (e.g., `CodeDetect2025!Secure`)
5. Click **"Add secret"**

**Why?** GitHub Actions needs this password to pass to Terraform when creating RDS.

---

### ✅ Step 2: Commit and Push Your Changes

```bash
cd C:\Users\kyaws\codeDetect

# Check what changed
git status

# You should see:
# - terraform/rds.tf (new)
# - terraform/billing-alerts.tf (new)
# - terraform/variables.tf (modified)
# - terraform/ec2.tf (modified)
# - docker-compose.yml (modified)
# - .github/workflows/deploy.yml (modified)

# Add all changes
git add .

# Commit
git commit -m "Add AWS RDS PostgreSQL Single-AZ with billing alerts"

# Push to GitHub
git push origin main
```

**What happens next:**
- GitHub Actions automatically triggers
- Runs tests
- Builds Docker image
- **Runs `terraform apply` automatically** ← Creates RDS!
- Deploys to AWS

---

### ✅ Step 3: Monitor GitHub Actions

1. Go to: https://github.com/Ntnick-22/codeDetect/actions
2. Click on the latest workflow run
3. Watch the progress:
   - ✅ Test job (~2 min)
   - ✅ Build Docker job (~3 min)
   - ✅ Deploy job (~15 min) ← **RDS created here!**

**Note:** RDS creation takes ~10-15 minutes (this is normal)

---

### ✅ Step 4: Verify RDS Was Created

After GitHub Actions completes:

**Option A: Check GitHub Actions Output**
```
Look for in the Deploy job logs:
✅ Terraform apply completed!
RDS endpoint: codedetect-prod-postgres.xxxxx.eu-west-1.rds.amazonaws.com
```

**Option B: Check AWS Console**
1. Go to AWS Console → RDS → Databases
2. You should see: `codedetect-prod-postgres`
3. Status: "Available" (after ~10-15 min)

**Option C: SSH into EC2 and check**
```bash
ssh -i codedetect-key ec2-user@<EC2_IP>

# Check environment
cat /home/ec2-user/app/.env | grep RDS

# Should show:
# RDS_ENDPOINT=codedetect-prod-postgres.xxxxx.rds.amazonaws.com:5432
# DB_NAME=codedetect
# DB_USERNAME=codedetect_admin
```

---

## What Gets Created Automatically

When you push, GitHub Actions creates:

1. **2 Private Subnets** (for RDS)
2. **1 RDS Subnet Group**
3. **1 RDS Security Group** (allows PostgreSQL from EC2 only)
4. **1 RDS PostgreSQL Instance** (db.t3.micro, 20GB)
5. **1 IAM Role** (for RDS monitoring)
6. **3 Billing Alarms** ($10, $20, $50 alerts)
7. **Updates EC2 instances** (to connect to RDS)

---

## Files Modified

```
✅ terraform/rds.tf                  (NEW - RDS configuration)
✅ terraform/billing-alerts.tf       (NEW - Cost alerts)
✅ terraform/variables.tf            (Modified - use_rds = true)
✅ terraform/ec2.tf                  (Modified - RDS connection)
✅ docker-compose.yml                (Modified - removed local PostgreSQL)
✅ .github/workflows/deploy.yml     (Modified - added db_password)
```

---

## Cost Monitoring

After deployment, you'll receive email alerts when AWS costs exceed:
- **$10/month** - Early warning
- **$20/month** - Approaching budget
- **$50/month** - Emergency alert

**To enable billing alerts:**
1. AWS Console → Billing Dashboard
2. Billing Preferences
3. ✅ Enable "Receive Billing Alerts"
4. Save

---

## Expected Timeline

| Time | What's Happening |
|------|------------------|
| T+0 min | Push code to GitHub |
| T+2 min | Tests pass |
| T+5 min | Docker image built |
| T+6 min | Terraform starts creating RDS |
| T+20 min | RDS created and available |
| T+25 min | EC2 instances updated |
| T+30 min | ✅ Deployment complete |

**Total: ~30 minutes** for first RDS deployment

---

## Troubleshooting

### GitHub Actions Fails with "db_password not set"
- Make sure you added `DB_PASSWORD` to GitHub Secrets
- Name must be exactly `DB_PASSWORD` (case-sensitive)

### Terraform Plan Shows "No changes"
- Check if `use_rds = true` in `terraform/variables.tf`
- Check all files were committed and pushed

### RDS Takes Too Long
- RDS creation normally takes 10-15 minutes
- This is normal AWS behavior, not an error

### Can't Connect to RDS from EC2
- Wait for GitHub Actions to fully complete
- Check `/var/log/codedetect-deploy.log` on EC2
- Verify RDS_ENDPOINT in `/home/ec2-user/app/.env`

---

## Next Deployment (After RDS Exists)

For future code changes:
```bash
# Make your code changes
git add .
git commit -m "Your changes"
git push origin main
```

**RDS will NOT be recreated!**
- Terraform detects RDS already exists
- Only updates EC2 instances with new code
- Database data persists

---

## Manual Terraform (If Needed)

If you ever need to run Terraform manually:

```bash
cd terraform

# View what would change
terraform plan -var="db_password=YourPassword123"

# Apply changes manually
terraform apply -var="db_password=YourPassword123"
```

**But you don't need this!** GitHub Actions does it automatically.

---

## Summary

✅ **NO manual `terraform apply` needed!**
✅ **Just `git push` and GitHub Actions deploys everything**
✅ **RDS will be created in ~15 minutes automatically**
✅ **Billing alerts set up automatically**
✅ **Both EC2 instances connect to same RDS**

**All you need to do:**
1. Add `DB_PASSWORD` to GitHub Secrets
2. `git push origin main`
3. Watch GitHub Actions deploy! 🚀

---

Generated: $(date)
