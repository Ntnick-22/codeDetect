# Demo Screenshot Checklist - High Availability Presentation

## Overview
This checklist ensures you capture all necessary screenshots to demonstrate your high-availability infrastructure.

**Total Screenshots Needed: ~15-20**

---

## Pre-Demo Preparation

### Before Taking Screenshots:

- [ ] All 4 instances are running (2 Blue + 2 Green)
- [ ] All target groups show "healthy" status
- [ ] Application is accessible via ALB DNS
- [ ] Browser is ready (clear cache, incognito mode optional)
- [ ] AWS Console is logged in
- [ ] Screenshot tool ready (Windows: Win+Shift+S, macOS: Cmd+Shift+4)

---

## Screenshot Categories

### 📸 Category 1: Infrastructure Overview (Before Failure)

#### Screenshot 1.1: EC2 Instances Dashboard
**Where:** AWS Console → EC2 → Instances

**What to show:**
- [ ] Filter by tag `Application=codedetect`
- [ ] All 4 instances in "running" state
- [ ] Instance IDs visible
- [ ] Different Availability Zones (eu-west-1a, eu-west-1b)
- [ ] Instance types (t3.micro)
- [ ] Launch time

**Filename:** `01-ec2-instances-all-running.png`

**Tips:**
- Use table view for clarity
- Show instance names: `codedetect-prod-blue-instance` and `codedetect-prod-green-instance`
- Highlight the 4 running instances

---

#### Screenshot 1.2: Blue Auto Scaling Group
**Where:** AWS Console → EC2 → Auto Scaling Groups → `codedetect-prod-blue-asg`

**What to show:**
- [ ] Group details tab
- [ ] Desired capacity: 2
- [ ] Min: 2, Max: 4
- [ ] Current capacity: 2
- [ ] Health check type: ELB
- [ ] 2 instances running in "InService" state

**Filename:** `02-blue-asg-details.png`

---

#### Screenshot 1.3: Green Auto Scaling Group
**Where:** AWS Console → EC2 → Auto Scaling Groups → `codedetect-prod-green-asg`

**What to show:**
- [ ] Group details tab
- [ ] Desired capacity: 2 (if green is active) or 0 (if blue is active)
- [ ] Instance count matching desired capacity

**Filename:** `03-green-asg-details.png`

---

#### Screenshot 1.4: Application Load Balancer
**Where:** AWS Console → EC2 → Load Balancers → `codedetect-prod-alb`

**What to show:**
- [ ] Load balancer name
- [ ] DNS name (important!)
- [ ] State: Active
- [ ] Availability Zones: 2
- [ ] Scheme: internet-facing
- [ ] Listeners: HTTP:80

**Filename:** `04-alb-overview.png`

---

#### Screenshot 1.5: Blue Target Group Health
**Where:** AWS Console → EC2 → Target Groups → `codedetect-prod-blue-tg` → Targets tab

**What to show:**
- [ ] **2 of 2 targets healthy** (key point!)
- [ ] Both instance IDs listed
- [ ] Health status: "healthy"
- [ ] Availability zones for each instance
- [ ] Port: 80

**Filename:** `05-blue-target-group-healthy.png`

**⭐ CRITICAL:** This shows high availability BEFORE failure

---

#### Screenshot 1.6: Green Target Group Health
**Where:** AWS Console → EC2 → Target Groups → `codedetect-prod-green-tg` → Targets tab

**What to show:**
- [ ] Health status of green instances
- [ ] If green is active: 2/2 healthy
- [ ] If green is inactive: 0/0 (no instances)

**Filename:** `06-green-target-group-status.png`

---

### 📸 Category 2: Application Working (Before Failure)

#### Screenshot 2.1: Application Homepage
**Where:** Browser → `http://<ALB-DNS-NAME>`

**What to show:**
- [ ] Application loads successfully
- [ ] URL bar showing ALB DNS name
- [ ] Full application interface
- [ ] No errors

**Filename:** `07-app-homepage-working.png`

---

#### Screenshot 2.2: Deployment Info - Instance 1
**Where:** Browser → `http://<ALB-DNS-NAME>/api/info`

**What to show:**
- [ ] JSON response with deployment information
- [ ] Note the `instance_id` (e.g., `i-0abc123def456`)
- [ ] Active environment (blue or green)
- [ ] Deployment time

**Filename:** `08-app-info-instance-1.png`

**Note:** Record this instance ID for comparison later

---

#### Screenshot 2.3: Deployment Info - Instance 2 (Load Balancing Proof)
**Where:** Browser → Refresh `/api/info` multiple times until different instance ID appears

**What to show:**
- [ ] Same endpoint, different `instance_id`
- [ ] Proves load balancing is working
- [ ] Both instances serving traffic

**Filename:** `09-app-info-instance-2.png`

**⭐ CRITICAL:** This proves load balancer distributes traffic across instances

---

### 📸 Category 3: Simulating Failure

#### Screenshot 3.1: Selecting Instance to Terminate
**Where:** AWS Console → EC2 → Instances

**What to show:**
- [ ] Select one of the running instances
- [ ] Highlight/check the instance
- [ ] Show instance ID clearly (note it down!)
- [ ] Instance state: running

**Filename:** `10-selecting-instance-to-terminate.png`

---

#### Screenshot 3.2: Termination Confirmation Dialog
**Where:** AWS Console → Instance State → Terminate Instance

**What to show:**
- [ ] Termination confirmation dialog
- [ ] Instance ID being terminated
- [ ] Warning message

**Filename:** `11-terminate-confirmation.png`

---

#### Screenshot 3.3: Instance Terminating
**Where:** AWS Console → EC2 → Instances (immediately after terminating)

**What to show:**
- [ ] 1 instance in "shutting-down" or "terminated" state
- [ ] 3 instances still running
- [ ] Terminated instance ID matches the one you selected

**Filename:** `12-instance-terminating.png`

---

### 📸 Category 4: Zero Downtime Proof (DURING Failure)

#### Screenshot 4.1: Target Group During Failure (Draining)
**Where:** AWS Console → EC2 → Target Groups → Active target group → Targets tab

**What to show:**
- [ ] **1 of 2 targets healthy** or **1 draining**
- [ ] One instance: "healthy"
- [ ] One instance: "draining" or "unhealthy"
- [ ] This shows real-time failure detection

**Filename:** `13-target-group-during-failure.png`

**⭐ CRITICAL:** Shows ALB detected failure and stopped sending traffic

---

#### Screenshot 4.2: Application STILL Working (Zero Downtime!)
**Where:** Browser → Refresh `http://<ALB-DNS-NAME>` immediately after termination

**What to show:**
- [ ] Application still loads perfectly
- [ ] No error message
- [ ] Same functionality
- [ ] Timestamp showing it's after termination

**Filename:** `14-app-still-working-during-failure.png`

**⭐ CRITICAL:** This is the KEY screenshot proving zero downtime!

---

#### Screenshot 4.3: Instance ID After Failure
**Where:** Browser → `/api/info` after failure

**What to show:**
- [ ] Only the healthy instance ID appears
- [ ] Compare with earlier screenshots (should be different)
- [ ] Proves traffic rerouted to healthy instance only

**Filename:** `15-app-info-healthy-instance-only.png`

---

### 📸 Category 5: Auto Scaling Recovery

#### Screenshot 5.1: Auto Scaling Activity
**Where:** AWS Console → EC2 → Auto Scaling Groups → Blue ASG → Activity tab

**What to show:**
- [ ] Activity showing instance termination detected
- [ ] New instance launch triggered
- [ ] Status: "Successful" or "In progress"
- [ ] Timestamps

**Filename:** `16-asg-activity-recovery.png`

**Note:** This may take 3-5 minutes after failure

---

#### Screenshot 5.2: New Instance Launching
**Where:** AWS Console → EC2 → Instances

**What to show:**
- [ ] New instance in "pending" or "running" state
- [ ] Instance ID is different from terminated one
- [ ] Total: 4 instances again (1 terminated, 1 new, 2 existing)

**Filename:** `17-new-instance-launching.png`

---

#### Screenshot 5.3: New Instance Healthy
**Where:** AWS Console → EC2 → Target Groups → Active TG → Targets

**What to show:**
- [ ] **2 of 2 targets healthy** again!
- [ ] New instance ID registered and healthy
- [ ] Old instance ID gone (deregistered)
- [ ] Full recovery complete

**Filename:** `18-target-group-recovered.png`

**⭐ CRITICAL:** Shows automatic recovery without manual intervention

---

### 📸 Category 6: Architecture Diagrams (Optional but Impressive)

#### Screenshot 6.1: VPC Resource Map
**Where:** AWS Console → VPC → Resource Map

**What to show:**
- [ ] VPC topology
- [ ] Public subnets in 2 AZs
- [ ] Internet Gateway
- [ ] Load balancer connections
- [ ] EC2 instances distribution

**Filename:** `19-vpc-resource-map.png`

---

#### Screenshot 6.2: CloudWatch Metrics (Optional)
**Where:** AWS Console → CloudWatch → Metrics → EC2

**What to show:**
- [ ] CPU utilization during failure
- [ ] Network traffic
- [ ] Drop/spike when instance terminated
- [ ] Recovery pattern

**Filename:** `20-cloudwatch-metrics.png`

---

## Screenshot Organization

### Folder Structure:

```
demo-screenshots/
├── 01-infrastructure-before/
│   ├── 01-ec2-instances-all-running.png
│   ├── 02-blue-asg-details.png
│   ├── 03-green-asg-details.png
│   ├── 04-alb-overview.png
│   ├── 05-blue-target-group-healthy.png
│   └── 06-green-target-group-status.png
│
├── 02-application-working/
│   ├── 07-app-homepage-working.png
│   ├── 08-app-info-instance-1.png
│   └── 09-app-info-instance-2.png
│
├── 03-failure-simulation/
│   ├── 10-selecting-instance-to-terminate.png
│   ├── 11-terminate-confirmation.png
│   └── 12-instance-terminating.png
│
├── 04-zero-downtime-proof/
│   ├── 13-target-group-during-failure.png
│   ├── 14-app-still-working-during-failure.png
│   └── 15-app-info-healthy-instance-only.png
│
└── 05-auto-recovery/
    ├── 16-asg-activity-recovery.png
    ├── 17-new-instance-launching.png
    └── 18-target-group-recovered.png
```

---

## Timeline for Capturing Screenshots

### Preparation Phase (15 minutes)
- ⏰ **T-15min**: Deploy infrastructure (`terraform apply`)
- ⏰ **T-10min**: Verify all instances healthy
- ⏰ **T-5min**: Test application accessibility
- ⏰ **T-0min**: Start screenshot capture

### Capture Phase 1: Before Failure (5 minutes)
- ⏱️ **Minute 1-2**: Infrastructure screenshots (EC2, ASG, ALB)
- ⏱️ **Minute 3**: Target group health screenshots
- ⏱️ **Minute 4-5**: Application working screenshots

### Capture Phase 2: During Failure (1-2 minutes)
- ⏱️ **Minute 1**: Terminate instance, capture confirmation
- ⏱️ **Minute 1.5**: Immediately check application (zero downtime proof!)
- ⏱️ **Minute 2**: Capture target group draining state

### Capture Phase 3: Recovery (5-10 minutes)
- ⏱️ **Minute 3-5**: Wait for Auto Scaling to detect failure
- ⏱️ **Minute 5-7**: Capture new instance launching
- ⏱️ **Minute 8-10**: Capture full recovery (2/2 healthy again)

**Total time: ~25-30 minutes**

---

## Screenshot Quality Tips

### Technical Requirements:
- [ ] **Resolution**: At least 1920x1080 (Full HD)
- [ ] **Format**: PNG (better quality than JPEG)
- [ ] **Size**: Keep each file under 5MB
- [ ] **Text readable**: Zoom out if needed to fit content

### Composition Tips:
- [ ] Hide unnecessary browser tabs/bookmarks
- [ ] Use incognito/private mode for clean browser
- [ ] Crop out taskbar/personal info
- [ ] Highlight key information (use red boxes/arrows if needed)
- [ ] Ensure timestamps are visible
- [ ] Keep consistent zoom level across similar screenshots

### AWS Console Tips:
- [ ] Expand columns to show all data
- [ ] Refresh to show latest state
- [ ] Use filters to reduce clutter
- [ ] Switch to table/grid view for clarity
- [ ] Click "Refresh" button before screenshot

---

## Annotating Screenshots (Optional but Recommended)

### Tools:
- **Windows**: Snip & Sketch, Paint, PowerPoint
- **macOS**: Preview, Keynote
- **Cross-platform**: GIMP, Photoshop, draw.io

### Annotations to Add:
- ✅ Green checkmarks for "healthy" states
- ❌ Red X for failed/terminated instances
- 🔴 Red circles/arrows pointing to key info
- 📝 Text labels explaining what's happening
- 🔢 Numbers showing sequence of events

### Example Annotations:

**Screenshot 5: Target Group Health**
```
┌─────────────────────────────────────┐
│ Target Group: codedetect-prod-blue  │
│                                     │
│ ✅ Instance i-abc123: Healthy       │ ← Add green checkmark
│ ✅ Instance i-def456: Healthy       │ ← Add green checkmark
│                                     │
│ 2 of 2 targets healthy ← Highlight this!
└─────────────────────────────────────┘
```

**Screenshot 13: During Failure**
```
┌─────────────────────────────────────┐
│ Target Group: codedetect-prod-blue  │
│                                     │
│ ✅ Instance i-abc123: Healthy       │ ← Still healthy
│ ⚠️  Instance i-def456: Draining     │ ← Add warning icon
│                                     │
│ 1 of 2 targets healthy ← Highlight!
└─────────────────────────────────────┘
```

---

## Critical Screenshots (Must Have!)

These are the **MINIMUM** screenshots you need for a successful demo:

### Top 5 Must-Have Screenshots:

1. ✅ **Screenshot 5**: Blue target group showing 2/2 healthy (before failure)
2. ✅ **Screenshot 14**: Application still working DURING failure (zero downtime proof!)
3. ✅ **Screenshot 13**: Target group showing 1/2 or "draining" (failure detected)
4. ✅ **Screenshot 18**: Target group back to 2/2 healthy (auto-recovery)
5. ✅ **Screenshot 1**: All 4 EC2 instances running

**If you only have time for 5 screenshots, take these!**

---

## Presentation Slide Suggestions

### Slide 1: Architecture Overview
- Title: "High Availability Architecture"
- Diagram showing ALB → Target Groups → EC2 instances
- Annotations: Multi-AZ, Auto Scaling, Health Checks

### Slide 2: Infrastructure Before Failure
- Screenshot: All 4 instances running
- Screenshot: 2/2 targets healthy
- Text: "Normal operation - traffic distributed across instances"

### Slide 3: Simulating Instance Failure
- Screenshot: Terminating instance
- Text: "Simulating real-world failure scenario"

### Slide 4: Zero Downtime Proof
- Screenshot: Application still working
- Screenshot: Target group showing 1/2 healthy
- Text: "Traffic automatically rerouted - users experience no downtime"
- **Big bold text: "0 seconds of downtime"**

### Slide 5: Automatic Recovery
- Screenshot: New instance launching
- Screenshot: 2/2 targets healthy again
- Text: "Auto Scaling automatically replaces failed instance"
- Timeline diagram showing recovery process

---

## Pre-Demo Test Run

Before your actual presentation, do a **practice run**:

- [ ] Deploy 4 instances (`terraform apply`)
- [ ] Verify all healthy
- [ ] Practice navigating AWS Console quickly
- [ ] Practice terminating instance
- [ ] Verify zero downtime works
- [ ] Time how long screenshots take
- [ ] Check screenshot quality/readability
- [ ] Scale back down (`terraform apply` with 1 instance)

**Practice makes perfect!**

---

## Emergency Backup Plan

If something goes wrong during demo:

### Plan A: Live Demo Failed
- Have screenshots ready as backup
- Walk through screenshots instead
- Explain: "Here's what happened when I tested earlier..."

### Plan B: Screenshots Failed
- Have architecture diagram ready
- Explain the concept verbally
- Offer to demo after presentation

### Plan C: Everything Failed
- Focus on Terraform code
- Show `loadbalancer.tf` configuration
- Explain Auto Scaling Groups, Target Groups, Health Checks conceptually
- Demonstrate understanding of infrastructure-as-code

---

## Final Checklist Before Presentation

- [ ] All screenshots captured and organized
- [ ] Screenshots are clear and readable
- [ ] Key information highlighted/annotated
- [ ] Slides prepared with screenshots embedded
- [ ] Backup copy of screenshots (USB drive/cloud)
- [ ] Practice run completed successfully
- [ ] Infrastructure scaled back down (cost savings)
- [ ] Terraform code reverted to production config
- [ ] Committed and pushed to GitHub

---

## Screenshot Storage Recommendations

### Local Backup:
```
C:\Users\kyaws\codeDetect\demo-screenshots\
```

### Cloud Backup:
- Google Drive folder
- OneDrive
- GitHub (create `docs/demo-screenshots/` folder)

### Presentation Files:
- Embed in PowerPoint/Keynote
- Export as PDF with screenshots
- Create video recording of demo (optional)

---

## Estimated File Sizes

| Category | Screenshots | Approx Size |
|----------|-------------|-------------|
| Infrastructure | 6 | 10-15 MB |
| Application | 3 | 5-8 MB |
| Failure Simulation | 3 | 5-8 MB |
| Zero Downtime | 3 | 5-8 MB |
| Recovery | 3 | 5-8 MB |
| **Total** | **18** | **30-47 MB** |

Easily fits on USB drive, email, cloud storage.

---

## Questions You Might Be Asked

Prepare screenshots to answer:

**Q: "How do you know load balancing is working?"**
A: Show screenshots 8 & 9 - same endpoint, different instance IDs

**Q: "What happens when instance fails?"**
A: Show screenshot 13 - target group detects failure within seconds

**Q: "Did users experience downtime?"**
A: Show screenshot 14 - application still working during failure!

**Q: "How long does recovery take?"**
A: Show timestamps on screenshots 16-18 - about 5 minutes for full recovery

**Q: "Is this automated?"**
A: Show screenshot 16 - Auto Scaling Activity showing automatic launch

---

Good luck with your presentation! 🎤📊

**Remember:** The most important screenshot is #14 (app still working during failure) - that's your "wow" moment! ✨
