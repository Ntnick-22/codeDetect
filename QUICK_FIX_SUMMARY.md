# SNS Auto-Unsubscribe - Quick Fix Summary

## What I Fixed

Your "SNS keeps unsubscribing" problem had **two root causes**:

### Problem #1: Application Configuration Missing
**Error you saw**: `"SNS not configured"`

**Location**: `backend/app.py:432`

The application couldn't find the `SNS_TOPIC_ARN` environment variable.

### Problem #2: Email Deliverability Issues
After you confirm the subscription, AWS auto-unsubscribes you because emails are bouncing or going to spam.

---

## Immediate Fix (For Local Testing Right Now)

### Step 1: Test Locally with .env File

I created `.env` file with:
```bash
SNS_TOPIC_ARN=arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback
```

**Test it now**:
```bash
# If running locally
cd /path/to/codeDetect
source .env  # Load variables
python backend/app.py

# Try the Report Issue feature - it should work now!
```

### Step 2: Fix Email Auto-Unsubscribe

**Whitelist AWS SNS in Gmail**:
1. Go to: https://mail.google.com/mail/u/0/#settings/filters
2. Create new filter
3. From: `no-reply@sns.amazonaws.com`
4. Actions:
   - ✅ Never send it to Spam
   - ✅ Always mark it as important
5. Create filter

This prevents Gmail from marking SNS emails as spam, which triggers auto-unsubscribe.

---

## Long-Term Fix (For Production on AWS)

I've created Terraform infrastructure to manage this properly:

### Files Created/Modified:

1. **`terraform/sns.tf`** (NEW)
   - Creates SNS topic for user feedback
   - Sets up email subscription
   - Configures permissions

2. **`terraform/secrets.tf:229-250`** (MODIFIED)
   - Stores SNS topic ARN in AWS Parameter Store
   - Your EC2 instances auto-load this on startup

3. **`terraform/outputs.tf:203-206`** (MODIFIED)
   - Shows SNS topic ARN after `terraform apply`

4. **`.env`** (CREATED for local dev)
   - For testing locally before deploying to AWS

### Deploy to Production:

```bash
cd terraform

# See what will be created
terraform plan

# Create the infrastructure
terraform apply

# You'll see:
# + aws_sns_topic.user_feedback (creates SNS topic)
# + aws_sns_topic_subscription.user_feedback_email (subscribes your email)
# + aws_ssm_parameter.sns_feedback_topic_arn (stores in Parameter Store)

# Type 'yes' to confirm
```

**IMPORTANT**: After terraform apply, check your email and **confirm the subscription** within 3 days!

---

## Why .env File?

### What is .env?

A `.env` file stores **environment variables** - configuration values that change between environments (local dev vs production).

### Why We Need It

Your Flask app (`backend/app.py`) reads configuration from environment variables:

```python
# Line 429 in app.py
topic_arn = os.environ.get('SNS_TOPIC_ARN')
```

`os.environ.get()` reads from environment variables. Without `.env`, Python can't find `SNS_TOPIC_ARN`.

### How It Works

```
.env file              →  Environment Variables  →  Python app
-----------------         -------------------      ------------
SNS_TOPIC_ARN=arn:...  →  os.environ dict      →  topic_arn variable
FLASK_ENV=development  →  os.environ dict      →  app.config
S3_BUCKET_NAME=...     →  os.environ dict      →  bucket_name
```

### Local vs Production

| Environment | How Config is Loaded | Where Config Stored |
|------------|---------------------|---------------------|
| **Local Dev** | From `.env` file | Your computer |
| **Production AWS** | From AWS Parameter Store | AWS cloud |

**On AWS EC2**:
1. `backend/entrypoint.sh` runs on startup
2. It fetches values from AWS Parameter Store
3. Exports them as environment variables
4. Flask app reads from those variables

**On Your Computer**:
1. You manually create `.env` file
2. Load it with `source .env` or docker-compose
3. Flask app reads from those variables

### Why .env is in .gitignore

**Security**: `.env` files contain sensitive data (API keys, secrets, ARNs)

From your `.gitignore:52`:
```gitignore
# Environment variables
.env
```

This prevents accidentally committing secrets to GitHub.

That's why we have:
- `.env.example` - Template (safe to commit)
- `.env` - Actual values (NEVER commit)

---

## What Happens on AWS EC2

### Startup Flow:

```
EC2 Instance Starts
    ↓
Docker container runs
    ↓
entrypoint.sh executes (backend/entrypoint.sh)
    ↓
Fetches secrets from AWS Parameter Store:
  - SECRET_KEY
  - S3_BUCKET_NAME
  - DATABASE_URL
  - SNS_TOPIC_ARN  ← THIS WAS MISSING BEFORE!
    ↓
Exports as environment variables
    ↓
Flask app starts with all config loaded
```

**Lines in entrypoint.sh:103-107**:
```bash
# Fetch SNS Topic ARN for user feedback
SNS_ARN=$(get_parameter "$PROJECT_NAME-$APP_ENV-sns-feedback-topic-arn")
if [ -n "$SNS_ARN" ]; then
    export SNS_TOPIC_ARN="$SNS_ARN"
fi
```

This was already there, but the Parameter Store value didn't exist!

My fix: `terraform/secrets.tf:236-250` creates the Parameter Store entry.

---

## Testing the Complete Fix

### Test 1: Local Development

```bash
# Create .env file (already done)
# It contains: SNS_TOPIC_ARN=arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback

# Run locally
cd backend
source ../.env
python app.py

# Open http://localhost:5000
# Click "Report Issue" → Fill form → Submit
# Should work without "SNS not configured" error
```

### Test 2: Production on AWS

```bash
# 1. Apply Terraform
cd terraform
terraform apply

# 2. Confirm email subscription (check inbox)

# 3. SSH into EC2
ssh -i codedetect-key ec2-user@<EC2_IP>

# 4. Check environment variable
echo $SNS_TOPIC_ARN
# Should output: arn:aws:sns:eu-west-1:...

# 5. Restart app
cd /home/ec2-user/app
docker-compose restart

# 6. Test Report Issue feature
# Open your website → Click "Report Issue" → Submit
# You should receive email!
```

---

## Why This is a Long-Term Fix

### Before (Manual, Fragile):
- ❌ SNS topic created manually via AWS Console
- ❌ Topic ARN hardcoded or missing
- ❌ Breaks when EC2 restarts
- ❌ No version control
- ❌ Can't reproduce in new environment

### After (Infrastructure-as-Code, Robust):
- ✅ SNS topic managed by Terraform
- ✅ Topic ARN stored in Parameter Store
- ✅ Auto-loaded on EC2 startup
- ✅ Version controlled
- ✅ Can rebuild anytime with `terraform apply`
- ✅ Works in dev, staging, prod (just change vars)

---

## Cost

**$0.00/month** - Everything is AWS Free Tier:
- SNS topic: Free
- Email notifications: First 1,000/month free
- Parameter Store: First 10,000 parameters free

---

## Files Reference

| File | Line Numbers | Purpose |
|------|-------------|---------|
| `backend/app.py` | 394-454 | Report submission endpoint |
| `backend/app.py` | 429 | Reads `SNS_TOPIC_ARN` env var |
| `backend/app.py` | 432 | Shows "SNS not configured" error |
| `backend/entrypoint.sh` | 103-107 | Loads SNS ARN from Parameter Store |
| `terraform/sns.tf` | All | SNS topic infrastructure |
| `terraform/secrets.tf` | 229-250 | Parameter Store for SNS ARN |
| `terraform/outputs.tf` | 203-206 | Output SNS ARN |
| `.env` | 18 | Local development config |

---

## Next Steps

### Immediate (Do This Now):
1. ✅ `.env` file created - test locally if needed
2. ✅ Whitelist AWS SNS in Gmail
3. ⏳ Apply Terraform changes
4. ⏳ Confirm email subscription

### Long-Term (Best Practices):
1. Monitor SNS delivery metrics in CloudWatch
2. Set up alarm for failed notifications
3. Consider using AWS SES for better email control
4. Document for team in wiki/confluence

---

## Need Help?

**Full documentation**: See `SNS_FIX_GUIDE.md`

**Terraform files**:
- `terraform/sns.tf` - SNS topic setup
- `terraform/secrets.tf` - Parameter Store config
- `terraform/outputs.tf` - Outputs

**Test scripts**:
- `fix-sns-subscription.sh` - Diagnostic tool
