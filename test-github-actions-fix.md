# Testing GitHub Actions Fix

## After Fixing IAM Permissions

### Option 1: Re-run Failed Workflow
1. Go to: https://github.com/Ntnick-22/codeDetect/actions
2. Click on the failed workflow run
3. Click **"Re-run all jobs"** button (top right)
4. Watch it run

### Option 2: Trigger New Deployment (Manual)
1. Go to: https://github.com/Ntnick-22/codeDetect/actions
2. Click on **"CI/CD - Docker Build & Blue/Green Deploy"**
3. Click **"Run workflow"** dropdown (right side)
4. Keep defaults or customize:
   - Docker tag: `test-fix`
   - Environment: `blue` or `green`
5. Click **"Run workflow"**
6. Watch the workflow run

### Option 3: Push a Small Change
```bash
# Make a small change
echo "# GitHub Actions Test" >> TEST.md
git add TEST.md
git commit -m "Test GitHub Actions after IAM fix"
git push origin main
```

This will trigger the CI/CD pipeline automatically.

## What to Watch For

### ✅ Success Indicators
- **test job**: Should pass (Pylint, Bandit, Docker build)
- **build-docker job**: Should build and push image to Docker Hub
- **deploy job**: Should:
  - Initialize Terraform ✅
  - Determine target environment ✅
  - Run Terraform plan ✅
  - Apply Terraform changes ✅
  - Wait for instances to be healthy ✅
  - Health check passes ✅

### ❌ If It Still Fails

Check which step fails:

**"Terraform Init" fails:**
- IAM user can't access S3 backend bucket
- Need S3 permissions for `codedetect-terraform-state-772297676546`

**"Terraform Plan" fails:**
- IAM user missing EC2/ASG/ALB/Route53 permissions
- Apply PowerUserAccess policy

**"Terraform Apply" fails:**
- Could be IAM permissions
- Could be resource conflict (check error message)

**"Wait for Instances" fails:**
- Instances might not be launching
- Check AWS Console → EC2 → Auto Scaling Groups
- Check target ASG has desired capacity > 0

**"Health Check" fails:**
- Application not responding
- Docker container might not be starting
- Check logs in AWS Console

## Expected Timeline

- **test job**: ~2-3 minutes
- **build-docker job**: ~3-5 minutes
- **deploy job**: ~10-15 minutes (most time is waiting for instances)

**Total**: ~15-20 minutes for full deployment

## Monitoring the Deployment

While it's running, you can monitor in parallel:

### CloudWatch Dashboard
```
https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=codedetect-prod-monitoring
```

### Auto Scaling Groups
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-blue-asg codedetect-prod-green-asg \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,Instances[*].[InstanceId,HealthStatus]]' \
  --output table
```

### Load Balancer Target Health
```bash
# Get target group ARNs
cd terraform
terraform output blue_target_group_arn
terraform output green_target_group_arn

# Check target health (use the active target group ARN)
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

## After Successful Deployment

1. **Check the application:**
   ```
   http://codedetect.nt-nick.link
   ```

2. **Verify via Load Balancer:**
   ```
   http://codedetect-prod-alb-1746261995.eu-west-1.elb.amazonaws.com
   ```

3. **Check which environment is active:**
   ```bash
   cd terraform
   terraform output active_environment
   ```

4. **View deployment summary:**
   ```bash
   cd terraform
   terraform output next_steps
   ```

## Troubleshooting Commands

```bash
# Check recent GitHub Actions runs
# (requires gh CLI)
gh run list --repo Ntnick-22/codeDetect --limit 5

# View specific run logs
gh run view <RUN_ID> --log --repo Ntnick-22/codeDetect

# Check AWS resources
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-blue-asg codedetect-prod-green-asg

aws elbv2 describe-load-balancers \
  --names codedetect-prod-alb

aws ec2 describe-instances \
  --filters 'Name=tag:Project,Values=CodeDetect' \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table
```
