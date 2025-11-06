# CI/CD Setup for Auto Scaling Group Deployment

## What Changed

**OLD (Single EC2):**
- SSH into one EC2 instance
- Pull code, rebuild Docker, restart container
- Requires SSH key in GitHub Secrets

**NEW (Auto Scaling Group):**
- Trigger Auto Scaling Group instance refresh
- Launches new instances with latest code automatically
- Zero downtime rolling deployment
- Requires AWS credentials in GitHub Secrets

## Required GitHub Secrets

Go to: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

Add these secrets:

### 1. AWS_ACCESS_KEY_ID
Your AWS access key ID

### 2. AWS_SECRET_ACCESS_KEY
Your AWS secret access key

### 3. How to Get AWS Credentials

```bash
# Option 1: Create IAM user for CI/CD
aws iam create-user --user-name github-cicd
aws iam attach-user-policy --user-name github-cicd --policy-arn arn:aws:iam::aws:policy/AutoScalingFullAccess
aws iam create-access-key --user-name github-cicd
```

Save the `AccessKeyId` and `SecretAccessKey` from the output.

## How Deployment Works Now

1. **Push to main branch**
2. **GitHub Actions runs:**
   - Test job: Pylint, Bandit, Radon, Docker build
   - Deploy job: Trigger instance refresh
3. **Auto Scaling Group:**
   - Launches new instance with latest code
   - Waits for health checks to pass
   - Terminates old instance
4. **Result:** Zero downtime deployment!

## Deployment Flow

```
Git Push → GitHub Actions → AWS Auto Scaling
   ↓            ↓                    ↓
  Code      Test & Build      Instance Refresh
                                     ↓
                          Launch New Instances
                                     ↓
                          Pull Latest Code (User Data)
                                     ↓
                          Build & Start Docker
                                     ↓
                          Health Checks Pass
                                     ↓
                          Terminate Old Instances
                                     ↓
                          ✅ Deployment Complete!
```

## Old Secrets (No Longer Needed)

You can delete these from GitHub Secrets:
- `EC2_HOST` (no single EC2 anymore)
- `EC2_USER` (no SSH deployment)
- `SSH_PRIVATE_KEY` (no SSH deployment)

Keep them if you want to SSH manually for debugging.

## Manual Deployment Trigger

You can manually trigger deployment from GitHub:
1. Go to `Actions` tab
2. Select `Deploy to EC2` workflow
3. Click `Run workflow`
4. Select `main` branch
5. Click green `Run workflow` button

## Monitoring Deployment

Watch deployment progress:
```bash
# Check instance refresh status
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name codedetect-prod-asg

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Test app
curl http://codedetect.nt-nick.link/api/health
```

## Troubleshooting

### "Refresh failed"
Check Auto Scaling Group events:
```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name codedetect-prod-asg \
  --max-records 5
```

### "Health checks failing"
Check instance logs:
```bash
# Get instance ID
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances \
  --query 'AutoScalingInstances[0].InstanceId' --output text)

# Get instance IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# SSH and check logs
ssh -i terraform/codedetect-key ec2-user@$INSTANCE_IP
docker logs codedetect-app
```

## Benefits of This Approach

✅ **Zero Downtime** - Rolling deployment keeps app running
✅ **Automatic** - No manual SSH needed
✅ **Scalable** - Works with 2, 4, or 100 instances
✅ **Reliable** - Health checks ensure new instances work before old ones terminate
✅ **Auditable** - All deployments logged in GitHub Actions
