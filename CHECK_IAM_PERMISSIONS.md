# GitHub Actions AWS Credentials Check

## What IAM User/Credentials Are GitHub Actions Using?

**GitHub Secrets Location:**
```
https://github.com/Ntnick-22/codeDetect/settings/secrets/actions
```

**Required secrets:**
- `AWS_ACCESS_KEY_ID` - Your IAM user access key
- `AWS_SECRET_ACCESS_KEY` - Your IAM user secret key

---

## Required IAM Permissions for GitHub Actions

The IAM user whose credentials are in GitHub Secrets needs these permissions:

### 1. **Terraform State Management (S3 + DynamoDB)**
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject"
  ],
  "Resource": [
    "arn:aws:s3:::codedetect-terraform-state-772297676546",
    "arn:aws:s3:::codedetect-terraform-state-772297676546/*"
  ]
}
```

### 2. **EC2 Management**
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:Describe*",
    "ec2:CreateTags",
    "ec2:RunInstances",
    "ec2:TerminateInstances",
    "ec2:ModifyInstanceAttribute",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:CreateSecurityGroup",
    "ec2:DeleteSecurityGroup"
  ],
  "Resource": "*"
}
```

### 3. **Auto Scaling**
```json
{
  "Effect": "Allow",
  "Action": [
    "autoscaling:Describe*",
    "autoscaling:CreateAutoScalingGroup",
    "autoscaling:UpdateAutoScalingGroup",
    "autoscaling:DeleteAutoScalingGroup",
    "autoscaling:CreateLaunchConfiguration",
    "autoscaling:DeleteLaunchConfiguration",
    "autoscaling:CreateOrUpdateTags",
    "autoscaling:SetDesiredCapacity"
  ],
  "Resource": "*"
}
```

### 4. **Load Balancer (ALB)**
```json
{
  "Effect": "Allow",
  "Action": [
    "elasticloadbalancing:Describe*",
    "elasticloadbalancing:CreateLoadBalancer",
    "elasticloadbalancing:DeleteLoadBalancer",
    "elasticloadbalancing:CreateTargetGroup",
    "elasticloadbalancing:DeleteTargetGroup",
    "elasticloadbalancing:CreateListener",
    "elasticloadbalancing:DeleteListener",
    "elasticloadbalancing:ModifyLoadBalancerAttributes",
    "elasticloadbalancing:ModifyTargetGroupAttributes",
    "elasticloadbalancing:AddTags"
  ],
  "Resource": "*"
}
```

### 5. **VPC Networking**
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:CreateVpc",
    "ec2:DeleteVpc",
    "ec2:CreateSubnet",
    "ec2:DeleteSubnet",
    "ec2:CreateInternetGateway",
    "ec2:DeleteInternetGateway",
    "ec2:AttachInternetGateway",
    "ec2:DetachInternetGateway",
    "ec2:CreateRouteTable",
    "ec2:DeleteRouteTable",
    "ec2:CreateRoute",
    "ec2:DeleteRoute",
    "ec2:AssociateRouteTable",
    "ec2:DisassociateRouteTable"
  ],
  "Resource": "*"
}
```

### 6. **IAM Role Management**
```json
{
  "Effect": "Allow",
  "Action": [
    "iam:GetRole",
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:AttachRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PutRolePolicy",
    "iam:DeleteRolePolicy",
    "iam:GetRolePolicy",
    "iam:CreateInstanceProfile",
    "iam:DeleteInstanceProfile",
    "iam:AddRoleToInstanceProfile",
    "iam:RemoveRoleFromInstanceProfile",
    "iam:GetInstanceProfile",
    "iam:PassRole"
  ],
  "Resource": "*"
}
```

### 7. **EFS (Elastic File System)**
```json
{
  "Effect": "Allow",
  "Action": [
    "elasticfilesystem:Describe*",
    "elasticfilesystem:CreateFileSystem",
    "elasticfilesystem:DeleteFileSystem",
    "elasticfilesystem:CreateMountTarget",
    "elasticfilesystem:DeleteMountTarget",
    "elasticfilesystem:CreateTags",
    "elasticfilesystem:DeleteTags"
  ],
  "Resource": "*"
}
```

### 8. **Route53 (DNS)**
```json
{
  "Effect": "Allow",
  "Action": [
    "route53:GetHostedZone",
    "route53:ListHostedZones",
    "route53:ListResourceRecordSets",
    "route53:ChangeResourceRecordSets",
    "route53:GetChange"
  ],
  "Resource": "*"
}
```

### 9. **ACM (SSL Certificates)**
```json
{
  "Effect": "Allow",
  "Action": [
    "acm:DescribeCertificate",
    "acm:ListCertificates",
    "acm:RequestCertificate",
    "acm:DeleteCertificate",
    "acm:AddTagsToCertificate"
  ],
  "Resource": "*"
}
```

### 10. **SNS (Notifications)**
```json
{
  "Effect": "Allow",
  "Action": [
    "sns:CreateTopic",
    "sns:DeleteTopic",
    "sns:Subscribe",
    "sns:Unsubscribe",
    "sns:SetTopicAttributes",
    "sns:GetTopicAttributes",
    "sns:ListSubscriptionsByTopic"
  ],
  "Resource": "*"
}
```

### 11. **CloudWatch (Monitoring & Alarms)**
```json
{
  "Effect": "Allow",
  "Action": [
    "cloudwatch:PutMetricAlarm",
    "cloudwatch:DeleteAlarms",
    "cloudwatch:DescribeAlarms"
  ],
  "Resource": "*"
}
```

### 12. **SSM Parameter Store**
```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:PutParameter",
    "ssm:GetParameter",
    "ssm:GetParameters",
    "ssm:DeleteParameter",
    "ssm:DescribeParameters",
    "ssm:AddTagsToResource"
  ],
  "Resource": "arn:aws:ssm:eu-west-1:772297676546:parameter/codedetect/prod/*"
}
```

### 13. **KMS (for SSM SecureString)**
```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "arn:aws:kms:eu-west-1:772297676546:key/alias/aws/ssm"
}
```

---

## How to Check Current IAM User Permissions

### Option 1: Via AWS Console
1. Go to: https://console.aws.amazon.com/iam/
2. Click "Users" in left sidebar
3. Find the IAM user whose credentials you added to GitHub
4. Click on the user
5. Go to "Permissions" tab
6. Check attached policies

### Option 2: Via AWS CLI (Using Your Credentials)
```bash
# Check which user the credentials belong to
aws sts get-caller-identity

# List attached policies
aws iam list-attached-user-policies --user-name YOUR_IAM_USERNAME

# Get policy details
aws iam get-user-policy --user-name YOUR_IAM_USERNAME --policy-name YOUR_POLICY_NAME
```

---

## Quick Permission Test

Run this to test if the GitHub Actions credentials have basic permissions:

```bash
# Export the credentials you added to GitHub
export AWS_ACCESS_KEY_ID="<your-github-secret-access-key-id>"
export AWS_SECRET_ACCESS_KEY="<your-github-secret-access-key>"
export AWS_DEFAULT_REGION="eu-west-1"

# Test S3 access (Terraform state)
aws s3 ls s3://codedetect-terraform-state-772297676546/

# Test EC2 describe
aws ec2 describe-instances --max-results 5

# Test Auto Scaling
aws autoscaling describe-auto-scaling-groups --max-records 5

# Test Load Balancer
aws elbv2 describe-load-balancers --names codedetect-prod-alb

# If any of these fail with "AccessDenied" or "UnauthorizedOperation"
# Then the IAM user needs those permissions
```

---

## Most Likely Issue: Missing Permissions

If GitHub Actions is failing with "exit code 1", it's probably one of these:

### Error Pattern 1: AccessDenied
```
Error: UnauthorizedOperation: You are not authorized to perform this operation
Error: AccessDenied: User is not authorized to perform: <action>
```
**Solution:** Add the missing permission to the IAM user

### Error Pattern 2: S3 Backend Access Denied
```
Error: error configuring S3 Backend: AccessDenied: Access Denied
```
**Solution:** IAM user needs S3 permissions for the state bucket

### Error Pattern 3: IAM PassRole Denied
```
Error: creating IAM Role: AccessDenied: User is not authorized to perform: iam:PassRole
```
**Solution:** Add `iam:PassRole` permission

---

## Recommended IAM Policy Setup

### Option A: Use AWS Managed Policy (Easiest)
Attach this managed policy to your IAM user:
- **PowerUserAccess** (broad permissions, easy setup)

**How to attach:**
1. Go to IAM Console
2. Click your user
3. Permissions → Add permissions → Attach policies directly
4. Search for "PowerUserAccess"
5. Click "Attach policy"

### Option B: Create Custom Policy (More Secure)
Create a custom policy with only the permissions listed above.

**Policy name:** `CodeDetectCICD`

Save this as a JSON policy and attach to your IAM user.

---

## Current Issue Diagnosis

Based on your question "is it cus of the new iam ?", here's what likely happened:

**Timeline:**
1. ✅ You created a new IAM user for GitHub Actions
2. ✅ You added credentials to GitHub Secrets
3. ❌ The IAM user doesn't have all required permissions
4. ❌ GitHub Actions fails when trying to create/modify AWS resources

**What to check:**
1. Does the IAM user have **PowerUserAccess** or equivalent?
2. Can the IAM user access the S3 backend bucket?
3. Does the IAM user have `iam:PassRole` permission?

---

## Quick Fix

**Fastest solution:**

1. Go to IAM Console: https://console.aws.amazon.com/iam/
2. Find your GitHub Actions IAM user
3. Click "Add permissions" → "Attach policies directly"
4. Search and attach: **PowerUserAccess**
5. Click "Add permissions"
6. Re-run the GitHub Actions workflow

This gives the user almost all permissions needed (except IAM user management, which you don't need).

---

## After Fixing Permissions

Once you've added the permissions:

1. **Re-run the failed workflow:**
   - Go to: https://github.com/Ntnick-22/codeDetect/actions
   - Click the failed run
   - Click "Re-run all jobs" (top right)

2. **Monitor the deployment:**
   - Watch the logs in real-time
   - Should complete in ~10 minutes if permissions are correct

---

## Verification Commands

After adding permissions, verify they work:

```bash
# Test with GitHub Actions credentials
export AWS_ACCESS_KEY_ID="<from-github-secret>"
export AWS_SECRET_ACCESS_KEY="<from-github-secret>"

# This should work now
aws s3 ls s3://codedetect-terraform-state-772297676546/

# This should also work
aws ec2 describe-instances --max-results 1

# If both work, permissions are good!
```

---

## Summary

**Most likely cause of "exit code 1":**
- New IAM user lacks required permissions
- Specifically: S3, EC2, Auto Scaling, Load Balancer, IAM PassRole

**Quickest fix:**
1. Go to IAM Console
2. Attach **PowerUserAccess** policy to your GitHub Actions IAM user
3. Re-run the GitHub Actions workflow

**How to verify:**
- Test the credentials with AWS CLI commands above
- Re-run GitHub Actions and check if it progresses further

Let me know what permissions your IAM user currently has and we'll fix it!
