# CloudWatch Alarms - Testing Guide

This guide shows how to test each alarm and which ones are actually useful for your project.

## Current Alarms (10 total)

### Category 1: CPU Alarms (Auto-Scaling) - ✅ KEEP THESE
**Purpose:** Trigger auto-scaling based on CPU load

1. **blue_cpu_high** - Scale up Blue ASG when CPU > 40%
2. **blue_cpu_low** - Scale down Blue ASG when CPU < 30%
3. **green_cpu_high** - Scale up Green ASG when CPU > 40%
4. **green_cpu_low** - Scale down Green ASG when CPU < 30%

**Already tested:** ✅ High CPU email alert works
**How to test:**
```bash
# SSH to an instance
ssh -i codedetect-key ec2-user@<INSTANCE_IP>

# Install stress tool
sudo yum install stress -y

# Test CPU high alarm (should trigger in 10 minutes)
stress --cpu 2 --timeout 600s

# Wait 10 minutes, check email and AWS console
# Should see: Email alert + New instance launched
```

**Why keep:** These are critical for auto-scaling. You've already tested high CPU successfully.

---

### Category 2: Instance Health - ⚠️ TEST OR REMOVE

#### 4. **instance_status_check** - EC2 instance down
**Purpose:** Alert when EC2 instance fails AWS health checks

**How to test:**
```bash
# Option 1: Stop an instance (easiest)
aws ec2 stop-instances --instance-ids <INSTANCE_ID>
# Wait 2 minutes, should trigger alarm

# Option 2: Simulate instance failure
ssh -i codedetect-key ec2-user@<INSTANCE_IP>
sudo shutdown -h now
```

**Recommendation:** ⚠️ **KEEP IF** you want alerts when instances crash
- Useful for debugging infrastructure issues
- ALB health checks already handle routing around failed instances
- If you trust ALB auto-healing, you can **REMOVE this**

---

#### 5. **unhealthy_targets** - Application down
**Purpose:** Alert when Flask app becomes unhealthy (Docker crash, app error)

**How to test:**
```bash
# SSH to an instance
ssh -i codedetect-key ec2-user@<INSTANCE_IP>

# Stop Docker (simulates app crash)
docker-compose down

# Wait 2 minutes, should trigger alarm
# Restart with: docker-compose up -d
```

**Recommendation:** ✅ **KEEP THIS** - Most important alarm!
- Detects when your application crashes
- Catches Docker issues, app bugs, dependency failures
- This is different from instance_status_check (catches app-level issues)

---

#### 6. **high_network_out** - Excessive network traffic
**Purpose:** Alert when network exceeds 100MB in 5 minutes (DDoS detection)

**How to test:**
```bash
# This is hard to test without generating real traffic
# You'd need to upload/download ~100MB in 5 minutes

# Easier: Manually trigger alarm for testing
aws cloudwatch set-alarm-state \
  --alarm-name codedetect-prod-high-network-out \
  --state-value ALARM \
  --state-reason "Testing alarm notification"

# Wait 1 minute, check email
# Reset to OK state
aws cloudwatch set-alarm-state \
  --alarm-name codedetect-prod-high-network-out \
  --state-value OK \
  --state-reason "Test complete"
```

**Recommendation:** ❌ **REMOVE THIS** for student project
- Very unlikely to hit 100MB/5min for a code analysis tool
- Hard to test without generating fake traffic
- Adds noise without real value for your use case

---

### Category 3: Billing Alarms - ✅ KEEP THESE

7. **billing_alarm_10** - Alert at $10/month
8. **billing_alarm_20** - Alert at $20/month
9. **billing_alarm_50** - Alert at $50/month

**How to test:**
```bash
# You can't easily test billing alarms without spending money
# But you can verify they exist:
aws cloudwatch describe-alarms --alarm-names \
  codedetect-prod-billing-alert-10-usd \
  codedetect-prod-billing-alert-20-usd \
  codedetect-prod-billing-alert-50-usd

# Manual trigger test
aws cloudwatch set-alarm-state \
  --alarm-name codedetect-prod-billing-alert-10-usd \
  --state-value ALARM \
  --state-reason "Testing billing notification"
```

**Recommendation:** ✅ **KEEP ALL THREE**
- Critical for cost control (you're a student!)
- No need to test - they'll work when you hit the threshold
- These have saved many students from surprise AWS bills

---

## Quick Test Commands

### Test Email Notifications (Without Real Triggers)
```bash
# Test any alarm by manually setting its state
aws cloudwatch set-alarm-state \
  --alarm-name <ALARM_NAME> \
  --state-value ALARM \
  --state-reason "Manual test"

# Example: Test unhealthy target alarm
aws cloudwatch set-alarm-state \
  --alarm-name codedetect-prod-unhealthy-targets \
  --state-value ALARM \
  --state-reason "Testing notification system"

# Wait 1 minute, check email

# Reset alarm
aws cloudwatch set-alarm-state \
  --alarm-name codedetect-prod-unhealthy-targets \
  --state-value OK \
  --state-reason "Test complete"
```

### List All Current Alarms
```bash
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[?starts_with(AlarmName, `codedetect-prod`)].[AlarmName,StateValue]' \
  --output table
```

### Check Alarm History
```bash
# See when alarms were triggered
aws cloudwatch describe-alarm-history \
  --alarm-name codedetect-prod-blue-cpu-high \
  --max-records 5
```

---

## Recommended Cleanup Plan

### Option 1: Minimal (Keep Only Essential) - Recommended for Student Project
**Keep:**
- ✅ CPU alarms (4 total) - Auto-scaling
- ✅ unhealthy_targets - App health
- ✅ Billing alarms (3 total) - Cost control

**Remove:**
- ❌ instance_status_check - Redundant with ALB health checks
- ❌ high_network_out - Unlikely to trigger, hard to test

**Total: 8 alarms (down from 10)**

### Option 2: Production-Ready (Keep Everything)
**Keep all 10 alarms** if:
- You're planning to put this on your resume as "production-ready"
- You want to show comprehensive monitoring knowledge
- You're okay with some alarms never triggering

---

## How to Remove Alarms

### Method 1: Comment Out in Terraform
Edit `terraform/monitoring.tf`:

```hcl
# REMOVED: Redundant with ALB health checks
# resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
#   ...
# }

# REMOVED: Unlikely to trigger for student project
# resource "aws_cloudwatch_metric_alarm" "high_network_out" {
#   ...
# }
```

Then apply:
```bash
cd terraform
terraform plan  # Review what will be deleted
terraform apply # Remove the alarms
```

### Method 2: Delete Directly in AWS (Quick Test)
```bash
# Delete specific alarms
aws cloudwatch delete-alarms \
  --alarm-names \
  codedetect-prod-instance-down \
  codedetect-prod-high-network-out

# WARNING: Terraform will recreate them on next apply unless you also remove from .tf files
```

---

## My Recommendation

For a **student project** focused on learning:

1. **Keep these 8 alarms:**
   - All CPU alarms (auto-scaling demo)
   - unhealthy_targets (app health)
   - All billing alarms (cost safety)

2. **Remove these 2 alarms:**
   - instance_status_check (redundant)
   - high_network_out (won't trigger)

3. **Testing strategy:**
   - ✅ Already tested: CPU high (works!)
   - Test unhealthy_targets: `docker-compose down` (5 min test)
   - Test billing alarms: Manual trigger (1 min test)
   - Skip: Network alarm (not worth the effort)

This gives you a clean, tested monitoring setup that you can confidently discuss in interviews:
- "I implemented CloudWatch monitoring with 8 alarms"
- "Auto-scaling based on CPU metrics"
- "Application health monitoring via ALB target health"
- "Cost control with billing alerts"
- "Tested all critical alarms successfully"

---

## Quick Action Plan

```bash
# 1. Test unhealthy targets alarm (2 minutes)
ssh -i codedetect-key ec2-user@<INSTANCE_IP>
docker-compose down
# Wait 2 min, check email, then: docker-compose up -d

# 2. Test billing alarm with manual trigger (1 minute)
aws cloudwatch set-alarm-state \
  --alarm-name codedetect-prod-billing-alert-10-usd \
  --state-value ALARM \
  --state-reason "Testing"

# 3. Remove unnecessary alarms (see next section)
```

Would you like me to help you remove the 2 unnecessary alarms?
