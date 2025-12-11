# Staging vs Production Environments

## Overview

This document explains the differences and similarities between staging and production environments, and how to promote changes from staging to production.

## Architecture Comparison

### What's the SAME (Environment Parity)

Both staging and production environments share the same architecture to ensure realistic testing:

| Component | Configuration | Why Same? |
|-----------|--------------|-----------|
| Database Type | RDS PostgreSQL | Catches RDS-specific issues before production |
| Monitoring | CloudWatch enabled | Ensures alerts and dashboards work identically |
| Deployment Method | Blue/Green via Terraform | Tests deployment process before production |
| Docker Images | Same codebase | Tests exact code that will run in production |
| Security Groups | Same rules | Tests firewall configurations |
| IAM Roles | Same permissions | Tests AWS access patterns |
| S3 Integration | Same setup | Tests file upload/storage behavior |
| ALB Health Checks | Same configuration | Tests load balancer routing |

### What's DIFFERENT (Cost Optimization)

Staging uses smaller scale to save costs while maintaining architectural parity:

| Component | Staging | Production | Reason |
|-----------|---------|------------|--------|
| Instance Type | t3.micro | t3.micro | Same (for consistency) |
| Instance Count | 1 per env | 1 per env | Same (minimal HA) |
| RDS Instance | db.t3.micro | db.t3.micro | Same (smallest size) |
| RDS Storage | 20 GB | 20 GB | Same (minimal) |
| Domain/SSL | Disabled | Enabled | Saves certificate costs |
| S3 Bucket | codedetect-staging-uploads-2025 | codedetect-prod-uploads-2025 | Separate data |
| Environment Tag | staging | production | For resource organization |

## Cost Breakdown

### Staging Environment
- EC2 (t3.micro): ~$8/month
- RDS PostgreSQL (db.t3.micro): ~$15/month
- EBS Storage (20GB): ~$2/month
- EFS Storage: ~$0.30/GB/month
- ALB: ~$16/month
- **Total if running 24/7**: ~$41/month
- **Total if running 8-10 hours/week**: ~$15-20/month

**Cost Saving Strategy**: Destroy staging when not testing:
```bash
terraform workspace select staging
terraform destroy -var-file="staging.tfvars"
```

### Production Environment
- EC2 (t3.micro): ~$8/month
- RDS PostgreSQL (db.t3.micro): ~$15/month
- EBS Storage (20GB): ~$2/month
- EFS Storage: ~$0.30/GB/month (production data)
- ALB: ~$16/month
- Route53: ~$0.50/month
- ACM Certificate: Free
- **Total**: ~$42/month

## Workflow: Staging to Production

### 1. Development Phase

Work in `main` branch for application code changes:

```bash
# Make code changes
git checkout main
vim backend/app.py

# Commit changes
git add .
git commit -m "Add new feature X"
git push origin main
```

This triggers CI/CD pipeline:
- Runs tests (pytest)
- Runs code quality checks (Pylint)
- Runs security scans (Bandit)
- Builds Docker image
- **Deploys to PRODUCTION automatically**

### 2. Infrastructure Testing in Staging

For infrastructure changes, test in staging first:

```bash
# Switch to staging branch
git checkout staging

# Make infrastructure changes
vim terraform/staging.tfvars

# Commit and push
git add terraform/staging.tfvars
git commit -m "Test new infrastructure configuration"
git push origin staging
```

Deploy to staging manually:

```bash
cd terraform
terraform workspace select staging
terraform plan -var-file="staging.tfvars" -var="db_password=$DB_PASSWORD"
terraform apply -var-file="staging.tfvars" -var="db_password=$DB_PASSWORD"
```

### 3. Testing in Staging

After deployment, test the staging environment:

```bash
# Get staging URL
terraform output load_balancer_dns

# Test health endpoint
curl http://STAGING_ALB_DNS/api/health

# Test file upload
# Test plagiarism detection
# Test monitoring/alerts
# Verify logs in CloudWatch
```

**What to test**:
- Application functionality
- Database operations (RDS PostgreSQL)
- File uploads to S3
- CloudWatch monitoring and alarms
- ALB health checks and routing
- Blue/Green deployment switching
- Performance under load

### 4. Promote to Production

Once staging tests pass:

**Option A: Infrastructure changes only**
```bash
# Copy tested configuration from staging to main
git checkout main
# Manually apply same changes to production.tfvars or variables.tf
git add terraform/
git commit -m "Apply tested infrastructure changes from staging"
git push origin main
```

**Option B: Application code changes**
- Already deployed to production via CI/CD
- No manual action needed (automated deployment)

**Option C: Both infrastructure + code**
```bash
# 1. Merge infrastructure changes
git checkout main
# Apply infrastructure changes
git merge staging  # Or cherry-pick specific commits

# 2. Deploy to production
cd terraform
terraform workspace select default  # Production workspace
terraform plan -var="db_password=$DB_PASSWORD"
terraform apply -var="db_password=$DB_PASSWORD"

# 3. Application code deploys automatically via CI/CD
```

### 5. Rollback Strategy

If production deployment fails:

**Rollback application (Blue/Green)**:
```bash
cd terraform
terraform apply -var="active_environment=blue"  # Switch back to previous environment
```

**Rollback infrastructure**:
```bash
terraform apply -var-file="previous-config.tfvars"
# Or use git to revert:
git revert <commit-hash>
git push origin main
```

## Branch Strategy

### Main Branch
- Contains production-ready code
- CI/CD automatically deploys to production on push
- Should always be stable
- Infrastructure files: `terraform/*.tf`, `variables.tf`

### Staging Branch
- Used for testing infrastructure changes
- Contains `terraform/staging.tfvars`
- Manual deployments only
- Test new configurations before production

## Common Workflows

### Test New Feature in Staging

```bash
# 1. Create feature branch from main
git checkout -b feature/new-plagiarism-algo

# 2. Make changes
vim backend/app.py

# 3. Build and test locally
docker build -t codedetect-test .
docker run -p 5000:5000 codedetect-test

# 4. Push to trigger CI/CD tests
git push origin feature/new-plagiarism-algo

# 5. Manually deploy to staging for integration testing
# (Build Docker image with staging tag)
docker build -t nyeinthunaing/codedetect:staging-test .
docker push nyeinthunaing/codedetect:staging-test

# 6. Deploy to staging
terraform workspace select staging
terraform apply -var-file="staging.tfvars" -var="docker_tag=staging-test"

# 7. Test in staging environment

# 8. Merge to main when ready
git checkout main
git merge feature/new-plagiarism-algo
git push origin main  # Auto-deploys to production
```

### Test Infrastructure Change

```bash
# 1. Switch to staging branch
git checkout staging

# 2. Modify staging infrastructure
vim terraform/staging.tfvars
# Example: Change instance_type = "t3.small"

# 3. Test deployment
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"

# 4. Verify changes work correctly
# Test for 1-2 days with real workload

# 5. Apply to production if successful
git checkout main
vim terraform/variables.tf  # Apply same change
git commit -m "Upgrade to t3.small (tested in staging)"
git push origin main

# 6. Deploy to production
terraform workspace select default
terraform apply
```

### Update Docker Image Version

**Automatic (Recommended)**:
- Push to main branch
- CI/CD builds and deploys automatically

**Manual (for specific version)**:
```bash
# 1. Build specific version
docker build -t nyeinthunaing/codedetect:v1.2.0 .
docker push nyeinthunaing/codedetect:v1.2.0

# 2. Deploy to staging first
terraform workspace select staging
terraform apply -var-file="staging.tfvars" -var="docker_tag=v1.2.0"

# 3. Test in staging

# 4. Deploy to production
terraform workspace select default
terraform apply -var="docker_tag=v1.2.0"
```

## Monitoring Both Environments

### CloudWatch Dashboards
- Staging: Filter by tag `Environment=staging`
- Production: Filter by tag `Environment=production`

### CloudWatch Alarms
- Both environments send alerts to configured email
- Staging alerts prefixed with `[STAGING]`
- Production alerts prefixed with `[PROD]`

### Logs
```bash
# View staging logs
aws logs tail /aws/ec2/codedetect-staging --follow

# View production logs
aws logs tail /aws/ec2/codedetect-production --follow
```

## Best Practices

1. **Always test in staging first** for infrastructure changes
2. **Use meaningful commit messages** to track what was tested
3. **Document test results** before promoting to production
4. **Keep staging configuration similar** to production (environment parity)
5. **Use fake data in staging** - no production secrets or real user data
6. **Destroy staging when not in use** to save costs
7. **Monitor both environments** with CloudWatch
8. **Use Blue/Green deployment** for zero-downtime updates
9. **Tag all resources** with environment labels
10. **Back up production data** regularly (RDS automated backups enabled)

## Terraform Workspaces

This project uses Terraform workspaces to manage environments:

```bash
# List workspaces
terraform workspace list

# Select staging
terraform workspace select staging

# Select production (default)
terraform workspace select default
```

**State files are separate per workspace**, preventing accidental cross-environment changes.

## Quick Reference

| Action | Staging | Production |
|--------|---------|------------|
| Deploy infrastructure | `terraform apply -var-file="staging.tfvars"` | `terraform apply` |
| Get URL | `terraform output load_balancer_dns` | `terraform output load_balancer_dns` |
| View logs | AWS Console: `Environment=staging` | AWS Console: `Environment=production` |
| Switch Blue/Green | `terraform apply -var-file="staging.tfvars" -var="active_environment=green"` | `terraform apply -var="active_environment=green"` |
| Destroy environment | `terraform destroy -var-file="staging.tfvars"` | **DO NOT DESTROY PRODUCTION** |
| Git branch | `staging` | `main` |
| Workspace | `staging` | `default` |

## Troubleshooting

### Staging deployment fails
1. Check Terraform error messages
2. Verify AWS credentials are configured
3. Check CloudWatch logs for instance startup issues
4. Verify security groups allow traffic
5. Ensure RDS instance is healthy

### Production out of sync with staging
1. Compare terraform state files
2. Run `terraform plan` in both environments
3. Document differences
4. Apply changes to staging first, then production

### Different behavior between staging and production
- Check environment variables (.env file)
- Verify Docker image tags match
- Compare Terraform configurations
- Check CloudWatch logs for errors
- Verify database migrations ran correctly

## Related Documentation

- `docs/INFRASTRUCTURE.md` - Overall infrastructure guide
- `docs/WORKFLOW_PRESENTATION.md` - CI/CD pipeline details
- `terraform/CLAUDE.md` - Terraform-specific instructions
- `.github/workflows/deploy.yml` - CI/CD pipeline configuration
