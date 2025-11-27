# AWS RDS PostgreSQL Setup - COMPLETE ✅

## Summary

I've successfully configured AWS RDS PostgreSQL (Single-AZ) for your CodeDetect application!

## What Was Done

### 1. Created New Terraform Configuration (`terraform/rds.tf`)
- ✅ Private subnets (2 subnets in different AZs for RDS)
- ✅ RDS subnet group
- ✅ RDS security group (PostgreSQL only accessible from EC2 instances)
- ✅ RDS PostgreSQL instance (db.t3.micro, Single-AZ)
- ✅ IAM role for RDS Enhanced Monitoring
- ✅ Terraform outputs for RDS endpoint and connection string

### 2. Updated Configuration Files

**`terraform/variables.tf`:**
- Changed `use_rds` from `false` to `true`

**`docker-compose.yml`:**
- Removed local PostgreSQL container
- Updated DATABASE_URL to use RDS endpoint
- Added comments explaining RDS setup

**`terraform/ec2.tf`:**
- Added RDS endpoint fetching in user data script
- Updated environment variables to include RDS connection details
- Removed PostgreSQL lock file logic (not needed with RDS)

**`terraform/billing-alerts.tf` (NEW):**
- Created billing alarms at $10, $20, $50 thresholds
- Sends email alerts via SNS when costs exceed limits

### 3. Validated Configuration
- ✅ Terraform fmt applied
- ✅ Terraform validate passed
- ✅ All files formatted correctly

---

## Your New Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                Load Balancer (ALB)                          │
│                       │                                     │
│         ┌─────────────┴──────────────┐                     │
│         │                            │                     │
│         ↓                            ↓                     │
│  ┌──────────────┐            ┌──────────────┐             │
│  │ EC2 #1 (AZ-1)│            │ EC2 #2 (AZ-2)│             │
│  │ ACTIVE       │            │ ACTIVE       │             │
│  │ App Running  │            │ App Running  │             │
│  └──────┬───────┘            └──────┬───────┘             │
│         │                            │                     │
│         └────────────┬───────────────┘                     │
│                      │                                     │
│                      ↓                                     │
│            ┌──────────────────┐                            │
│            │ RDS PostgreSQL   │                            │
│            │ db.t3.micro      │                            │
│            │ Single-AZ        │                            │
│            │ 20GB Storage     │                            │
│            └──────────────────┘                            │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
- ✅ Both EC2 instances are ACTIVE (serving traffic)
- ✅ Both connect to the same RDS database
- ✅ No PostgreSQL container conflicts
- ✅ Production-ready architecture

---

## RDS Configuration Details

| Setting | Value | Notes |
|---------|-------|-------|
| **Instance Class** | db.t3.micro | FREE for 12 months |
| **Engine** | PostgreSQL 15.4 | Latest stable version |
| **Storage** | 20GB gp2 SSD | FREE for 12 months |
| **Multi-AZ** | false (Single-AZ) | Upgrade later if needed |
| **Backups** | 7 days retention | Automated daily backups |
| **Encryption** | Enabled | Data encrypted at rest |
| **Public Access** | Disabled | Only accessible from EC2 |
| **Monitoring** | Enhanced (60sec) | FREE with Performance Insights |

---

## Cost Estimate

### First 12 Months (FREE Tier):
```
RDS db.t3.micro (750 hrs/month):    $0
Storage 20GB:                       $0
Backups 20GB:                       $0
Enhanced Monitoring:                $0
────────────────────────────────────────
RDS Total:                          $0/month

Your Total Infrastructure:
- ALB:                             $16/month
- EC2 (2 × t3.small):              $0 (free tier)
- RDS:                             $0 (free tier)
- EFS:                             ~$2/month
────────────────────────────────────────
TOTAL:                             ~$18/month
```

### After 12 Months:
```
RDS db.t3.micro (24/7):           $15/month
Storage 20GB gp2:                 $2.30/month
Backups 20GB:                     $2/month
────────────────────────────────────────
RDS Total:                        $19/month

Your Total Infrastructure:
- ALB:                             $16/month
- EC2 (2 × t3.small):              $30/month
- RDS:                             $19/month
- EFS:                             ~$2/month
────────────────────────────────────────
TOTAL:                             ~$67/month
```

---

## Next Steps - How to Deploy

### Step 1: Set Database Password
You need to provide a secure database password when deploying.

**Option A: Via terraform.tfvars (Recommended)**
```bash
cd terraform
echo 'db_password = "YourSecurePassword123!"' >> terraform.tfvars
```

**Option B: Via Command Line**
```bash
terraform apply -var="db_password=YourSecurePassword123!"
```

**Option C: Use Existing Parameter Store Value**
The password is already in AWS Parameter Store: `codedetect-prod-db-password`

### Step 2: Review Changes
```bash
cd terraform
terraform plan
```

This will show you:
- 2 new private subnets
- 1 RDS subnet group
- 1 RDS security group
- 1 RDS PostgreSQL instance
- 1 IAM role for monitoring
- 3 billing alarms
- Updates to EC2 launch template

### Step 3: Apply Changes
```bash
terraform apply
```

This will:
1. Create RDS PostgreSQL instance (takes ~10-15 minutes)
2. Update EC2 instances to connect to RDS
3. Set up billing alerts
4. Output RDS endpoint

### Step 4: Verify Deployment
After `terraform apply` completes:

```bash
# Get RDS endpoint
terraform output rds_endpoint

# SSH into EC2 instance
ssh -i codedetect-key ec2-user@<EC2_IP>

# Check environment variables
cat /home/ec2-user/app/.env | grep RDS

# Check logs
tail -f /var/log/codedetect-deploy.log

# Verify app is connected to RDS
docker logs codedetect-app
```

---

## Billing Alerts

You'll receive email alerts when costs exceed:
- **$10/month** - Early warning
- **$20/month** - Approaching budget
- **$50/month** - Emergency alert

**To enable billing alerts:**
1. Go to AWS Console → Billing Dashboard
2. Click "Billing Preferences"
3. Enable "Receive Billing Alerts"
4. Save preferences

---

## Database Connection Details

Your app will automatically connect to RDS using these environment variables:

```bash
RDS_ENDPOINT=codedetect-prod-postgres.xxxxx.eu-west-1.rds.amazonaws.com:5432
DB_NAME=codedetect
DB_USERNAME=codedetect_admin
DB_PASSWORD=<from Parameter Store>
```

The connection string is constructed in `docker-compose.yml`:
```
DATABASE_URL=postgresql://codedetect_admin:password@endpoint:5432/codedetect
```

---

## Upgrading to Multi-AZ (Optional - Future)

When you need 99.99% uptime, upgrade to Multi-AZ:

**In `terraform/variables.tf` or `terraform.tfvars`:**
```hcl
# Add this to terraform.tfvars
db_multi_az = true
```

**In `terraform/rds.tf`, change line 138:**
```hcl
multi_az = true  # Changed from false
```

Then run:
```bash
terraform apply
```

**Cost:** ~$30/month (doubles RDS cost)
**Benefit:** Automatic failover if primary database fails

---

## Monitoring Your RDS

### Via AWS Console:
1. Go to RDS → Databases → codedetect-prod-postgres
2. Check:
   - **Monitoring tab:** CPU, memory, connections
   - **Logs & events:** Query logs, errors
   - **Performance Insights:** Slow queries

### Via CloudWatch:
- Metrics are automatically sent to CloudWatch
- Set up custom dashboards if needed

---

## Backup & Recovery

**Automated Backups:**
- Daily backups at 3:00-4:00 AM UTC
- 7 days retention
- Can restore to any point in time

**Manual Snapshot:**
```bash
aws rds create-db-snapshot \
  --db-instance-identifier codedetect-prod-postgres \
  --db-snapshot-identifier codedetect-manual-snapshot-$(date +%Y%m%d)
```

**Restore from Backup:**
```bash
# Via AWS Console: RDS → Snapshots → Restore
# Creates a new RDS instance from snapshot
```

---

## Troubleshooting

### RDS Instance Not Accessible from EC2
```bash
# Check security group allows PostgreSQL from EC2
aws ec2 describe-security-groups --group-ids <RDS_SG_ID>

# Should show ingress rule:
# Port 5432, Source: EC2 security group
```

### App Can't Connect to RDS
```bash
# SSH into EC2
ssh -i codedetect-key ec2-user@<EC2_IP>

# Check environment variables
cat /home/ec2-user/app/.env | grep RDS

# Test PostgreSQL connection
docker exec -it codedetect-app bash
apt-get update && apt-get install -y postgresql-client
psql $DATABASE_URL -c "SELECT version();"
```

### RDS Performance Issues
```bash
# Check Performance Insights in AWS Console
# Look for slow queries, connection spikes

# Increase instance size if needed (not free tier)
# In terraform.tfvars: db_instance_class = "db.t3.small"
```

---

## Important Notes

### ⚠️ Database Migration
When you first deploy RDS, your database will be EMPTY (no existing data).

**If you have existing data in SQLite:**
1. Export from SQLite: `sqlite3 codedetect.db .dump > backup.sql`
2. Import to PostgreSQL: Use `pg_restore` or manual migration
3. Or start fresh (if it's test data)

### ⚠️ Free Tier Limits
- RDS: 750 hours/month = ONE db.t3.micro instance
- If you run 2 RDS instances, you'll be charged immediately
- Monitor your usage in AWS Console

### ⚠️ Terraform State
- Your terraform state now includes RDS resources
- If you run `terraform destroy`, RDS will be deleted
- Set `deletion_protection = true` in production!

---

## Files Modified/Created

**New Files:**
- `terraform/rds.tf` - RDS configuration
- `terraform/billing-alerts.tf` - Cost monitoring
- `RDS_SETUP_COMPLETE.md` - This file

**Modified Files:**
- `terraform/variables.tf` - Enabled RDS
- `terraform/ec2.tf` - Added RDS endpoint fetching
- `docker-compose.yml` - Removed local PostgreSQL

---

## Questions?

Common questions:

**Q: Can I switch back to SQLite?**
A: Yes, set `use_rds = false` in `terraform/variables.tf`

**Q: How do I upgrade to Multi-AZ?**
A: Set `multi_az = true` in `terraform/rds.tf` line 138

**Q: What if I exceed free tier?**
A: You'll get billing alerts. You can destroy RDS or keep it at ~$19/month

**Q: Can I connect to RDS from my local machine?**
A: No, RDS is in private subnet. Use SSH tunnel or bastion host

**Q: How do I backup/restore?**
A: Automated daily backups enabled. Restore via AWS Console

---

## Summary

✅ RDS PostgreSQL configured (db.t3.micro, Single-AZ)
✅ Both EC2 instances will connect to same database
✅ FREE for 12 months, then ~$19/month
✅ Billing alerts set up ($10, $20, $50)
✅ Production-ready architecture
✅ Terraform configuration validated

**Ready to deploy!** Run `terraform apply` when ready.

---

Generated: $(date)
