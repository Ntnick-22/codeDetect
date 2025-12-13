# GitHub Secrets Setup Guide

This guide explains how to configure GitHub Secrets for your CodeDetect deployment.

## Why Use GitHub Secrets?

GitHub Secrets allow you to store sensitive information (passwords, emails, API keys) securely **without hardcoding them in your code**. This is important when:
- You want to share your code publicly
- You want to keep credentials private
- You follow security best practices

## Required Secrets

Your project needs these GitHub Secrets:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for deployments | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `DB_PASSWORD` | Database password | `SecurePassword123!` |
| `DOCKER_HUB_TOKEN` | Docker Hub access token | `dckr_pat_xxxxx` |
| `NOTIFICATION_EMAIL` | Your email for SNS alerts | `your-email@gmail.com` |

## How to Add Secrets

### Step 1: Go to Repository Settings

1. Open your GitHub repository
2. Click **Settings** (top navigation)
3. In the left sidebar, click **Secrets and variables** → **Actions**

### Step 2: Add Each Secret

For each secret above:

1. Click **New repository secret**
2. Enter the **Name** (e.g., `NOTIFICATION_EMAIL`)
3. Enter the **Value** (e.g., `your-email@gmail.com`)
4. Click **Add secret**

Repeat for all 5 secrets.

### Step 3: Verify Secrets Are Set

You should see all 5 secrets listed:
- ✅ AWS_ACCESS_KEY_ID
- ✅ AWS_SECRET_ACCESS_KEY
- ✅ DB_PASSWORD
- ✅ DOCKER_HUB_TOKEN
- ✅ NOTIFICATION_EMAIL

## How the Secrets Are Used

### In Production Workflow (`.github/workflows/deploy.yml`)

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}

- name: Terraform Plan
  run: |
    terraform plan \
      -var="db_password=${{ secrets.DB_PASSWORD }}" \
      -var="notification_email=${{ secrets.NOTIFICATION_EMAIL }}"
```

### In Staging Workflow (`.github/workflows/staging.yml`)

```yaml
- name: Terraform Apply for Staging
  run: |
    terraform apply -auto-approve \
      -var-file="staging.tfvars" \
      -var="db_password=${{ secrets.DB_PASSWORD }}" \
      -var="notification_email=${{ secrets.NOTIFICATION_EMAIL }}"
```

## Benefits of This Approach

✅ **Security**: Email and passwords are not in Git history
✅ **Flexibility**: Change email without editing code
✅ **Safe to share**: Can make repository public without exposing credentials
✅ **Team-friendly**: Each team member can use their own email
✅ **Best practice**: Industry-standard approach for CI/CD secrets

## Testing After Setup

After adding the secrets, test the deployment:

1. **Push a commit** to the `main` branch
2. **Check GitHub Actions** tab to see if workflow succeeds
3. **Check your email** for SNS confirmation
4. **Confirm the subscription** by clicking the link in the email

## Troubleshooting

### "Secret not found" error
- Make sure the secret name exactly matches (case-sensitive)
- Check that you added it to **Actions secrets**, not **Dependabot secrets**

### Email not received after deployment
1. Check spam folder
2. Verify `NOTIFICATION_EMAIL` secret is set correctly
3. Check CloudWatch logs for SNS errors
4. Run the diagnostic script: `./scripts/check-sns-setup.sh`

### Workflow still uses hardcoded values
- Make sure workflows reference `${{ secrets.NOTIFICATION_EMAIL }}`
- Check that variables.tf has generic defaults, not hardcoded values

## Security Notes

⚠️ **Never commit secrets to Git!**
⚠️ **Don't print secret values in logs** (GitHub masks them automatically, but be careful)
⚠️ **Rotate credentials regularly** (especially AWS keys)
⚠️ **Use least-privilege IAM policies** for AWS credentials

## Alternative: Local Development

For local Terraform testing (without GitHub Actions):

```bash
# Option 1: Use .tfvars file (don't commit this!)
echo 'notification_email = "your-email@gmail.com"' > terraform/terraform.tfvars

# Option 2: Pass via command line
terraform apply -var="notification_email=your-email@gmail.com"

# Option 3: Set environment variable
export TF_VAR_notification_email="your-email@gmail.com"
terraform apply
```

## Summary

By using GitHub Secrets:
- Your email is **secure** and **not exposed in code**
- Your repository can be **safely made public**
- You follow **security best practices**
- Your CI/CD pipeline **works automatically**

The workflows now pass your email from GitHub Secrets → Terraform → AWS SNS → Your inbox! 📧✨
