# Test Auto-Recovery & Auto Scaling

## Scenario 1: Simulate Instance Crash (Container Failure)

### What This Tests:
- Load Balancer health checks detect unhealthy instance
- Auto Scaling replaces failed instance
- New instance auto-deploys
- Zero downtime (if you have 2 instances)

### Steps:

**1. SSH into EC2:**
```bash
ssh -i terraform/codedetect-key ec2-user@54.217.136.169
```

**2. Stop the Docker container (simulate app crash):**
```bash
# Stop the application container
docker-compose stop

# Or kill it completely
docker stop codedetect-app
```

**3. What happens:**
- **0:00** - Container stops
- **0:30** - Load Balancer health check fails (`/api/health` returns error)
- **1:30** - Second health check fails (unhealthy threshold: 2)
- **1:30** - ALB marks instance as "unhealthy" and stops sending traffic
- **2:30** - Auto Scaling detects unhealthy instance
- **3:00** - Auto Scaling TERMINATES the instance
- **3:01** - Auto Scaling LAUNCHES new instance
- **5:00** - New instance boots, runs user data, deploys app
- **6:00** - Health checks pass, ALB sends traffic to new instance

**4. Monitor:**
- AWS Console → EC2 → Auto Scaling Groups → Activity History
- AWS Console → EC2 → Load Balancers → Target Groups → Health status
- Email: You'll get alarm notification

---

## Scenario 2: Terminate Instance Manually (Quickest Test)

### What This Tests:
- Auto Scaling maintains desired capacity
- New instance launches automatically
- Infrastructure as Code (user data script runs)

### Steps:

**1. Get current instance ID:**
```bash
# In AWS Console: EC2 → Instances
# Or via CLI:
aws ec2 describe-instances --region eu-west-1 --filters "Name=tag:Name,Values=codedetect-prod-blue*" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table
```

**2. Terminate the instance:**

**Option A - AWS Console:**
- Go to EC2 → Instances
- Select your instance
- Actions → Instance State → Terminate

**Option B - AWS CLI:**
```bash
aws ec2 terminate-instances --instance-ids i-xxxxx --region eu-west-1
```

**3. What happens:**
- **0:00** - Instance terminated
- **0:01** - Auto Scaling detects: "Desired=1, Current=0"
- **0:02** - Auto Scaling launches new instance
- **3:00** - New instance boots
- **3:01** - User data script runs (install Docker, pull image, deploy)
- **5:00** - Health checks start passing
- **5:30** - ALB adds instance to target pool
- **6:00** - Instance fully operational

**4. Expected Timeline:**
- **Downtime**: ~5 minutes (with 1 instance)
- **Downtime**: 0 seconds (with 2 instances - other instance handles traffic)

---

## Scenario 3: Test Load Balancer Failover (Requires 2 Instances)

### What This Tests:
- Load balancer distributes traffic across instances
- When one fails, all traffic goes to healthy instance
- Zero downtime

### Setup (Increase to 2 instances):

**1. Update Terraform:**
```bash
cd terraform
# Edit variables.tf or use command line:
terraform apply -var="desired_capacity=2"
```

**2. Wait for 2nd instance to launch (~5 min)**

**3. Verify both instances healthy:**
- AWS Console → Load Balancers → Target Groups
- Should see: 2/2 healthy targets

**4. Kill one instance:**
```bash
# Terminate one instance (use Console or CLI)
aws ec2 terminate-instances --instance-ids i-xxxxx
```

**5. What happens:**
- **0:00** - Instance 1 terminates
- **0:00** - Load Balancer detects (health check fails)
- **0:30** - ALB stops sending traffic to Instance 1
- **0:30** - ALL traffic now goes to Instance 2 (zero downtime!)
- **1:00** - Auto Scaling detects: need to replace
- **1:01** - Auto Scaling launches new instance
- **5:00** - New instance ready
- **5:30** - Back to 2/2 healthy targets

**Result**: **ZERO DOWNTIME** - users never notice!

---

## Scenario 4: Test Status Check Alarm

### What This Tests:
- CloudWatch instance status check alarm
- Email notification when instance becomes unhealthy

### Steps:

**1. Cause status check failure (simulate hardware/OS issue):**

**Option A - Kernel panic (EXTREME - will kill instance):**
```bash
# SSH into instance
sudo sh -c 'echo 1 > /proc/sys/kernel/sysrq'
sudo sh -c 'echo c > /proc/sysrq-trigger'
# Instance immediately crashes
```

**Option B - Stop Docker and networking (safer):**
```bash
# Stop all services
sudo systemctl stop docker
sudo systemctl stop network
```

**2. What happens:**
- **0:00** - Services stop
- **1:00** - Status check fails
- **2:00** - Second consecutive failure
- **2:00** - CloudWatch alarm: `codedetect-prod-instance-down` triggers
- **2:01** - Email sent via SNS
- **3:00** - Auto Scaling detects unhealthy
- **3:01** - Terminates and replaces instance

---

## Scenario 5: Scale Up Test (Auto Scaling based on CPU)

### What This Tests:
- Auto Scaling responds to high load
- Scales from 1 to 2 instances automatically
- Load Balancer distributes traffic

### Current Auto Scaling Policy:
- **Scale UP**: When CPU > 70% for 5 minutes
- **Scale DOWN**: When CPU < 30% for 10 minutes

### Steps:

**1. Check current scaling config:**
```bash
cd terraform
grep -A 5 "scale_up" loadbalancer.tf
```

**2. Trigger scale-up:**
```bash
# SSH into instance
ssh -i terraform/codedetect-key ec2-user@54.217.136.169

# Run CPU stress for 10 minutes (longer than eval period)
sudo amazon-linux-extras install epel -y
sudo yum install -y stress
stress --cpu 2 --timeout 600s  # 10 minutes
```

**3. What happens:**
- **0:00** - CPU spikes to 100%
- **5:00** - CPU >70% for 5 consecutive minutes
- **5:01** - Auto Scaling policy triggers: scale up
- **5:02** - Auto Scaling launches 2nd instance
- **8:00** - 2nd instance becomes healthy
- **8:30** - Load Balancer adds 2nd instance
- **Result**: Now have 2 instances sharing load!

**4. After stress ends:**
- **10:00** - Stress test ends, CPU drops
- **20:00** - CPU <30% for 10 minutes
- **20:01** - Auto Scaling policy triggers: scale down
- **20:02** - Auto Scaling terminates 1 instance
- **Result**: Back to 1 instance

---

## Quick Comparison Table

| Test Scenario | Downtime | New Instance? | Load Balancer Tested? | Email Alert? |
|---------------|----------|---------------|----------------------|--------------|
| High CPU (stress test) | 0 sec | ❌ No | ❌ No | ✅ Yes |
| Stop Docker container | ~5 min | ✅ Yes | ✅ Yes | ✅ Yes |
| Terminate instance | ~5 min | ✅ Yes | ✅ Yes | ❌ No* |
| Kill one of 2 instances | 0 sec | ✅ Yes | ✅ Yes | ❌ No* |
| Kernel panic | ~5 min | ✅ Yes | ✅ Yes | ✅ Yes |
| CPU-based auto-scaling | 0 sec | ✅ Yes (adds) | ✅ Yes | ❌ No* |

*Depends on whether alarm thresholds are breached during recovery

---

## Recommended Test for Demo/Presentation

**Best Option: Terminate instance and show recovery**

```bash
# 1. Show current setup
aws ec2 describe-instances --region eu-west-1 --filters "Name=tag:Name,Values=*codedetect*" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table

# 2. Note the instance ID (e.g., i-0abc123)

# 3. Show application is working
curl http://codedetect.nt-nick.link/api/health

# 4. Terminate instance
aws ec2 terminate-instances --instance-ids i-0abc123 --region eu-west-1

# 5. Show application down (for ~5 min)
curl http://codedetect.nt-nick.link/api/health
# Should fail or timeout

# 6. Watch Auto Scaling launch new instance
# AWS Console → Auto Scaling Groups → Activity

# 7. Wait ~5 minutes

# 8. Show application back online
curl http://codedetect.nt-nick.link/api/health
# Should return healthy response

# 9. Show new instance (different instance ID)
aws ec2 describe-instances --region eu-west-1 --filters "Name=tag:Name,Values=*codedetect*" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table
```

---

## For ZERO Downtime Demo (Requires 2 Instances)

```bash
# 1. Scale to 2 instances
cd terraform
terraform apply -var="desired_capacity=2"

# 2. Wait for both healthy (~5 min)

# 3. Show both instances in Load Balancer
# AWS Console → Load Balancers → Target Groups → Should show 2/2 healthy

# 4. Keep application running in background
while true; do curl -s http://codedetect.nt-nick.link/api/health && echo " - $(date)"; sleep 2; done

# 5. In another terminal, kill one instance
aws ec2 terminate-instances --instance-ids i-xxxxx

# 6. Watch the curl loop - should NEVER fail!
# Load balancer immediately routes to healthy instance

# 7. Auto Scaling launches replacement
# Watch Activity History

# 8. After ~5 min, back to 2/2 healthy
```

---

## Summary: What You Should Test

**For Presentation:**
1. ✅ **Terminate instance** - Shows Auto Scaling recovery (5 min downtime)
2. ✅ **Scale to 2 instances** - Shows Load Balancer distributing traffic
3. ✅ **Kill one of 2 instances** - Shows ZERO downtime failover

**For Understanding:**
- High CPU = Monitoring works ✅ (you already tested this!)
- Instance failure = Auto-recovery works
- Multiple instances = High availability works

---

Want me to help you set up the **2-instance zero-downtime test**? That's the most impressive for presentations!
