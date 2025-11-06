# CodeDetect Monitoring Plan

## Phase 1A: Basic Infrastructure Monitoring (Today)

### 1. EC2 CloudWatch Metrics (Built-in)
These are automatically collected by AWS:
- CPUUtilization
- NetworkIn/NetworkOut
- StatusCheckFailed

**No code needed - AWS does this automatically!**

### 2. CloudWatch Agent (Custom Metrics)
We'll install an agent on EC2 to collect:
- Memory utilization (not collected by default)
- Disk utilization (not collected by default)
- Swap usage

**Why agent needed:** AWS can't see inside your EC2 without permission.

### 3. CloudWatch Alarms
We'll create alarms for:

| Alarm Name | Metric | Threshold | Action |
|------------|--------|-----------|--------|
| high-cpu | CPU > 80% | 5 minutes | Email alert |
| high-memory | Memory > 85% | 5 minutes | Email alert |
| disk-full | Disk > 90% | 1 check | Email alert |
| instance-down | StatusCheck fail | 2 checks | Email alert |

### 4. SNS Topic
Email notification system:
- Topic: codedetect-alerts
- Subscription: your email
- Confirms subscription first

### 5. CloudWatch Dashboard
Visual display showing:
- CPU graph (last 3 hours)
- Memory graph (last 3 hours)
- Network graph (last 3 hours)
- Alarm status widgets

---

## Phase 1B: Application Logging (Next Session)

### 1. CloudWatch Logs
We'll send Docker container logs to CloudWatch:
- Log Group: /aws/ec2/codedetect
- Log Stream: per container
- Retention: 7 days (free tier)

### 2. Log Insights Queries
Pre-built queries:
- Count errors in last hour
- Top 10 slowest requests
- Failed uploads

---

## Phase 1C: Custom Application Metrics (Advanced)

### Flask Application Modifications
Add custom metric reporting:
- Analysis count (using CloudWatch PutMetric)
- Average analysis time
- S3 upload success rate

**Note:** This requires small code changes to backend/app.py

---

## What We'll Build TODAY (Phase 1A)

**Time estimate:** 1-2 hours
**Cost:** ~$1-2/month

**Deliverables:**
1. CloudWatch Agent running on EC2
2. 4 alarms configured
3. Email alerts working
4. Dashboard visible

**Skills demonstrated:**
- CloudWatch metrics
- CloudWatch alarms
- SNS notifications
- Infrastructure monitoring
- Terraform for monitoring resources

---

## File Structure

We'll create these new Terraform files:

```
terraform/
├── monitoring.tf          # Alarms and SNS
├── cloudwatch-agent.tf    # Agent configuration
├── variables.tf           # Add email variable
└── outputs.tf             # Add dashboard URL
```

**Why separate files?**
- Better organization
- Easier to understand
- Can enable/disable monitoring independently
- Professional practice

---

Ready to start?
