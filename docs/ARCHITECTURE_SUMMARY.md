# CodeDetect Architecture Summary

## ✅ ACTUAL PRODUCTION CONFIGURATION

### Database: AWS RDS PostgreSQL (NOT SQLite!)

**Confirmed via AWS CLI:**
```
RDS Instance: codedetect-prod-postgres
Status: available (running)
Endpoint: codedetect-prod-postgres.c7240amye8by.eu-west-1.rds.amazonaws.com
Engine: PostgreSQL
Instance Class: db.t3.micro
```

**Why RDS is used:**
- `variables.tf` default: `use_rds = true` (line 123)
- CI/CD workflow does NOT pass `-var-file=production.tfvars`
- Therefore, Terraform uses defaults from `variables.tf`
- `production.tfvars` shows `use_rds = false` but is IGNORED by CI/CD

**CI/CD only passes these variables:**
```yaml
terraform plan \
  -var="active_environment=$TARGET_ENV" \
  -var="docker_tag=$DOCKER_TAG" \
  -var="db_password=${{ secrets.DB_PASSWORD }}" \
  -var="notification_email=${{ secrets.NOTIFICATION_EMAIL }}"
```

Note: `use_rds` is NOT passed, so default `true` is used!

---

## Architecture Layers

### 1. User Workflow
```
User → Upload Code → S3 (temp) → Analysis Engine → RDS PostgreSQL → Dashboard
```

**Key Components:**
- **S3**: Temporary file storage during analysis
- **Analysis Engine**: Pylint, Bandit, Radon
- **RDS PostgreSQL**: Persistent storage for aggregate metrics
- **Privacy**: Only stores scores/counts, NO code content

### 2. CI/CD Deployment
```
GitHub Push → Tests → Build Image → Push to Docker Hub → Terraform Apply → EC2 Pull Image → Run Container → Blue-Green Switch → Production
```

**Key Points:**
- GitHub Actions **builds** the Docker image
- EC2 instances **pull** pre-built images (do NOT build)
- Blue-green deployment for zero downtime

### 3. Infrastructure
```
Internet → IGW → ALB → Target Group → Blue/Green ASG → RDS PostgreSQL + S3
```

**Database Access:**
- Both Blue and Green ASGs connect to same RDS instance
- RDS handles concurrent connections (no file locking needed like SQLite)
- Database endpoint configured via Parameter Store

**Storage:**
- **RDS PostgreSQL**: Analysis results (permanent)
- **S3**: File uploads (temporary)
- **EFS**: Not used (migrated to RDS for better reliability)

### 4. Monitoring & Alerting

**Two SNS Topics:**

1. **codedetect-prod-alerts** (Infrastructure)
   - Source: CloudWatch Alarms
   - Triggers: High CPU, unhealthy targets, errors
   - Email: nyeinthunaing322@gmail.com
   - Status: ✅ **WORKING**

2. **codedetect-prod-user-feedback** (User Reports)
   - Source: Dashboard feedback form
   - Triggers: POST /api/report
   - Email: nyeinthunaing322+feedback@gmail.com
   - Status: ❌ **BOUNCING** (Gmail blacklisted this topic)

**Auto-Scaling:**
- Scale UP: CPU > 70% for 5 minutes
- Scale DOWN: CPU < 30% for 5 minutes
- Min: 1 instance, Max: 3 instances

---

## Cost Analysis

### Current Monthly Costs (~$31/month):

| Service | Cost | Notes |
|---------|------|-------|
| ALB | $16/month | 24/7 load balancer |
| EC2 (t3.micro) | $7.50/month | Free tier year 1, $15/month after |
| RDS (db.t3.micro) | $15/month | PostgreSQL database |
| S3 | <$1/month | Temporary uploads |
| CloudWatch | $0 | Within free tier limits |
| **Total** | **~$31/month** | After free tier expires: ~$46/month |

**Why RDS instead of SQLite on EFS:**
- ✅ Automated backups (7 days retention)
- ✅ Multi-AZ support for high availability
- ✅ No file locking issues with concurrent writes
- ✅ Better reliability and data integrity
- ❌ Additional cost (~$15/month vs ~$0.30/month for EFS)

---

## Corrected Diagrams

Updated files:
1. `docs/diagrams/1-user-workflow.drawio` - Shows RDS PostgreSQL
2. `docs/diagrams/3-infrastructure.drawio` - Shows RDS instead of EFS+SQLite
3. `docs/TECHNICAL_REPORT_CONTENT_PLAN.md` - Updated requirements section

All diagrams now correctly show **AWS RDS PostgreSQL** as the database.

---

## Key Learnings

1. **production.tfvars is ignored by CI/CD workflow**
   - Only used for local development/testing
   - CI/CD uses defaults from `variables.tf`

2. **Always verify actual deployed resources**
   - Don't rely on tfvars files alone
   - Use `aws rds describe-db-instances` to confirm

3. **Two notification channels with different statuses**
   - CloudWatch alerts work perfectly
   - User feedback bounces due to Gmail spam filtering per SNS topic ARN

---

Generated: 2025-12-14
Last Updated: After discovering RDS is actually deployed, not SQLite
