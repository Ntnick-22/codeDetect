# ============================================================================
# CODEDETECT - CLOUDWATCH MONITORING & ALERTING
# ============================================================================
# This file sets up production-grade monitoring:
# - SNS topic for notifications
# - CloudWatch alarms for critical metrics
# - Email alerts when thresholds are breached
#
# WHAT this does: Monitors your EC2 and sends alerts when problems occur
# WHY we need it: You can't watch AWS Console 24/7 - automated alerts are essential
# HOW it works: CloudWatch checks metrics → Triggers alarm → SNS emails you
# ============================================================================

# ----------------------------------------------------------------------------
# SNS TOPIC - The Notification Hub
# ----------------------------------------------------------------------------

# WHAT: SNS (Simple Notification Service) Topic
# This is like a "channel" or "bulletin board" where alerts get posted
# Other services (CloudWatch alarms) will publish messages here
# Subscribers (your email) will receive these messages

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  # Display name appears in email subject line
  # Example: "[CodeDetect-prod-alerts] High CPU Usage"
  display_name = "CodeDetect Infrastructure Alerts"

  # Tags help organize resources in AWS Console
  tags = merge(
    local.common_tags,
    {
      Name      = "${local.name_prefix}-alerts"
      Purpose   = "Infrastructure monitoring and alerting"
      AlertType = "Email"
    }
  )
}

# ----------------------------------------------------------------------------
# SNS SUBSCRIPTION - Connect Your Email
# ----------------------------------------------------------------------------

# WHAT: SNS Subscription
# This connects YOUR EMAIL to the topic above
# When alarm triggers → SNS topic gets message → Your email receives it

# WHY separate resource: One topic can have many subscribers
# You could add: email, SMS, Slack, PagerDuty, Lambda function, etc.

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email # Your email from variables.tf

  # IMPORTANT: After 'terraform apply', AWS will send confirmation email
  # You MUST click the confirmation link or you won't get alerts!
  # Check spam folder if you don't see it
}

# ----------------------------------------------------------------------------
# CLOUDWATCH ALARM 1: High CPU Usage
# ----------------------------------------------------------------------------

# WHAT: CloudWatch Alarm for CPU monitoring
# Checks if EC2 CPU usage exceeds 80% for sustained period

# WHY 80%: Industry standard threshold
# - Below 70% = Normal operation
# - 70-80% = Getting busy, keep eye on it
# - 80-90% = High load, investigate
# - 90%+ = Critical, may cause slowness

# WHY 5 minutes (3 x 60 seconds):
# Prevents false alarms from temporary spikes
# Example: Brief CPU spike during deployment won't trigger alarm

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "${local.name_prefix}-high-cpu"
  alarm_description = "Alert when EC2 CPU exceeds 80% for 5 minutes"

  # What metric to monitor
  namespace   = "AWS/EC2"        # AWS service
  metric_name = "CPUUtilization" # Built-in EC2 metric
  statistic   = "Average"        # Use average (not max/min)

  # Comparison logic
  comparison_operator = "GreaterThanThreshold" # CPU > threshold
  threshold           = 80                     # 80%

  # Time-based settings
  period             = 60 # Check every 60 seconds
  evaluation_periods = 5  # Must exceed for 5 checks
  # Formula: Must be high for (period x evaluation_periods) = 5 minutes

  # What to monitor (which EC2 instance)
  dimensions = {
    InstanceId = aws_instance.main.id
  }

  # What to do when alarm triggers
  alarm_actions = [
    aws_sns_topic.alerts.arn # Send notification to SNS topic
  ]

  # Optional: What to do when alarm recovers (goes back to normal)
  ok_actions = [
    aws_sns_topic.alerts.arn # Notify that problem is resolved
  ]

  # Treat missing data as "not breaching" (instance might be stopped)
  treat_missing_data = "notBreaching"

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-high-cpu-alarm"
      Severity = "Warning"
      Resource = "EC2"
    }
  )
}

# ----------------------------------------------------------------------------
# CLOUDWATCH ALARM 2: Instance Status Check Failed
# ----------------------------------------------------------------------------

# WHAT: Monitors AWS's automated health checks on your EC2
# AWS runs 2 types of checks every minute:
# 1. System Status Check - AWS hardware/network issues
# 2. Instance Status Check - Your EC2 OS issues

# WHY this matters:
# If checks fail → Instance is unhealthy → App is down
# This detects problems faster than waiting for users to complain

resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  alarm_name        = "${local.name_prefix}-instance-down"
  alarm_description = "Alert when EC2 instance status check fails"

  # Status check metric
  namespace   = "AWS/EC2"
  metric_name = "StatusCheckFailed" # Combines both check types
  statistic   = "Maximum"           # If any check fails

  # Comparison: 1 = failed, 0 = passed
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0 # Alert on ANY failure

  # Check every minute, trigger after 2 consecutive failures
  period             = 60 # 1 minute
  evaluation_periods = 2  # 2 failures = 2 minutes down

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  treat_missing_data = "notBreaching"

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-instance-down-alarm"
      Severity = "Critical" # Instance down = CRITICAL
      Resource = "EC2"
    }
  )
}

# ----------------------------------------------------------------------------
# CLOUDWATCH ALARM 3: High Network Out (Traffic Spike)
# ----------------------------------------------------------------------------

# WHAT: Monitors outbound network traffic from EC2
# Useful for detecting:
# - Unexpected traffic spike (possible DDoS victim)
# - Data exfiltration attempts
# - Misconfigured application causing network flood

# WHY 100MB threshold:
# - Normal web app: <10MB/5min
# - Busy web app: 10-50MB/5min
# - Very busy: 50-100MB/5min
# - Suspicious: >100MB/5min

resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  alarm_name        = "${local.name_prefix}-high-network-out"
  alarm_description = "Alert when network traffic exceeds 100MB in 5 minutes"

  namespace   = "AWS/EC2"
  metric_name = "NetworkOut" # Bytes sent from instance
  statistic   = "Sum"        # Total bytes in period

  comparison_operator = "GreaterThanThreshold"
  threshold           = 104857600 # 100 MB in bytes

  period             = 300 # 5 minutes
  evaluation_periods = 1   # Trigger immediately

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  treat_missing_data = "notBreaching"

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-high-network-alarm"
      Severity = "Warning"
      Resource = "EC2"
    }
  )
}

# ----------------------------------------------------------------------------
# INTERVIEW TALKING POINTS
# ----------------------------------------------------------------------------

# When discussing this in interviews:

# 1. "Why SNS instead of direct email from CloudWatch?"
#    Answer: Decoupling. SNS lets you add more notification channels later
#    (Slack, PagerDuty, SMS) without modifying alarms. It's also free tier eligible.

# 2. "Why these specific thresholds?"
#    Answer: Based on instance size (t3.small) and application type (web app).
#    Thresholds should be tuned based on baseline metrics after running in production.

# 3. "What about false positives?"
#    Answer: Using evaluation_periods prevents transient spikes from triggering.
#    In production, I'd use AWS Lambda to implement "smart alerting" with
#    dynamic thresholds based on time of day and historical patterns.

# 4. "How do you test these alarms?"
#    Answer: Use AWS CLI to set alarm state manually:
#    aws cloudwatch set-alarm-state --alarm-name <name> --state-value ALARM --state-reason "Testing"

# 5. "What's missing from this setup?"
#    Answer: Memory and disk metrics (need CloudWatch Agent - next file)
#    Log-based alarms (Phase 1B), composite alarms for complex logic,
#    and anomaly detection for dynamic thresholds.

# ----------------------------------------------------------------------------
# CLOUDWATCH DASHBOARD - Visual Monitoring Console
# ----------------------------------------------------------------------------

# WHAT: CloudWatch Dashboard
# Visual display of all important metrics in one place
# Like a car dashboard showing speed, fuel, temperature

# WHY: Quick operational visibility
# - Check health in 10 seconds (not 10 minutes of clicking around)
# - Spot trends and correlations visually
# - Great for troubleshooting incidents
# - Impressive for interviews/demos

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-monitoring"

  # Dashboard body is JSON defining layout and widgets
  # We use Terraform's jsonencode() to write this cleanly
  dashboard_body = jsonencode({
    # Dashboard widgets are arranged in a grid
    # Each widget has: x, y, width, height (in grid units)
    # Grid is 24 units wide
    widgets = [
      # ===================================================================
      # ROW 1: TITLE AND ALARM STATUS
      # ===================================================================

      # Widget 1: Dashboard Title
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# 📊 CodeDetect Infrastructure Monitoring\n**Instance:** ${aws_instance.main.id} | **IP:** ${aws_eip.main.public_ip} | **Region:** ${var.aws_region}"
        }
      },

      # Widget 2: Alarm Status Overview
      {
        type   = "alarm"
        x      = 0
        y      = 1
        width  = 24
        height = 3
        properties = {
          title = "🚨 Alarm Status"
          alarms = [
            aws_cloudwatch_metric_alarm.high_cpu.arn,
            aws_cloudwatch_metric_alarm.instance_status_check.arn,
            aws_cloudwatch_metric_alarm.high_network_out.arn
          ]
        }
      },

      # ===================================================================
      # ROW 2: CPU METRICS
      # ===================================================================

      # Widget 3: CPU Utilization Graph (12 hours)
      {
        type   = "metric"
        x      = 0
        y      = 4
        width  = 18
        height = 6
        properties = {
          title  = "CPU Utilization (%)"
          region = var.aws_region
          # Metrics to display: [Namespace, MetricName, DimensionName, DimensionValue]
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.main.id, { stat = "Average", label = "Avg CPU", color = "#1f77b4" }],
            ["...", { stat = "Maximum", label = "Max CPU", color = "#ff7f0e" }]
          ]
          # Time period shown
          period = 300 # 5-minute intervals
          stat   = "Average"
          # Graph appearance
          yAxis = {
            left = {
              min   = 0
              max   = 100
              label = "Percentage"
            }
          }
          # Add horizontal line at alarm threshold
          annotations = {
            horizontal = [{
              value = 80
              label = "Alarm Threshold"
              color = "#d62728" # Red line
            }]
          }
        }
      },

      # Widget 4: Current CPU (number display)
      {
        type   = "metric"
        x      = 18
        y      = 4
        width  = 6
        height = 3
        properties = {
          title  = "Current CPU"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.main.id]
          ]
          period = 60
          stat   = "Average"
          # Display as single number (not graph)
          view = "singleValue"
          # Set precision
          setPeriodToTimeRange = true
        }
      },

      # Widget 5: CPU Maximum (number display)
      {
        type   = "metric"
        x      = 18
        y      = 7
        width  = 6
        height = 3
        properties = {
          title  = "Peak CPU (Last Hour)"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.main.id, { stat = "Maximum" }]
          ]
          period = 3600 # 1 hour
          stat   = "Maximum"
          view   = "singleValue"
        }
      },

      # ===================================================================
      # ROW 3: NETWORK METRICS
      # ===================================================================

      # Widget 6: Network In/Out Graph
      {
        type   = "metric"
        x      = 0
        y      = 10
        width  = 12
        height = 6
        properties = {
          title  = "Network Traffic (Bytes)"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.main.id, { stat = "Sum", label = "Inbound", color = "#2ca02c" }],
            [".", "NetworkOut", ".", ".", { stat = "Sum", label = "Outbound", color = "#d62728" }]
          ]
          period = 300 # 5 minutes
          stat   = "Sum"
          yAxis = {
            left = {
              label = "Bytes"
              min   = 0
            }
          }
        }
      },

      # Widget 7: Network Packets
      {
        type   = "metric"
        x      = 12
        y      = 10
        width  = 12
        height = 6
        properties = {
          title  = "Network Packets"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkPacketsIn", "InstanceId", aws_instance.main.id, { stat = "Sum", label = "Packets In" }],
            [".", "NetworkPacketsOut", ".", ".", { stat = "Sum", label = "Packets Out" }]
          ]
          period = 300
          stat   = "Sum"
        }
      },

      # ===================================================================
      # ROW 4: STATUS CHECKS
      # ===================================================================

      # Widget 8: Status Check Graph
      {
        type   = "metric"
        x      = 0
        y      = 16
        width  = 12
        height = 6
        properties = {
          title  = "Instance Status Checks"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.main.id, { label = "Any Check Failed", color = "#d62728" }],
            [".", "StatusCheckFailed_System", ".", ".", { label = "System Check Failed", color = "#ff7f0e" }],
            [".", "StatusCheckFailed_Instance", ".", ".", { label = "Instance Check Failed", color = "#8c564b" }]
          ]
          period = 60
          stat   = "Maximum"
          yAxis = {
            left = {
              min   = 0
              max   = 1
              label = "Status (0=OK, 1=Failed)"
            }
          }
        }
      },

      # Widget 9: Disk Operations (if available)
      {
        type   = "metric"
        x      = 12
        y      = 16
        width  = 12
        height = 6
        properties = {
          title  = "Disk I/O Operations"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "DiskReadOps", "InstanceId", aws_instance.main.id, { stat = "Sum", label = "Read Ops" }],
            [".", "DiskWriteOps", ".", ".", { stat = "Sum", label = "Write Ops" }]
          ]
          period = 300
          stat   = "Sum"
        }
      }
    ]
  })

  # Note: CloudWatch Dashboards don't support tags
  # Tags can only be applied to alarms, topics, and other resources
}

# ============================================================================
# DASHBOARD EXPLANATION FOR INTERVIEWS
# ============================================================================

# When discussing dashboards in interviews:

# 1. "What's on your monitoring dashboard?"
#    - Key metrics: CPU, memory, network, disk, alarms
#    - Both current values and trends (last 3-12 hours)
#    - Alarm status for quick red/green health check
#    - Annotations showing threshold lines

# 2. "Why these specific metrics?"
#    - CPU: Detects performance bottlenecks and runaway processes
#    - Network: Spots traffic anomalies, DDoS, or connectivity issues
#    - Status checks: AWS-level health (hardware, network, OS)
#    - Historical view: Identify patterns (traffic spike at 9 AM every day)

# 3. "How do you handle too many metrics?"
#    - Use multiple dashboards: Overview, Detailed, Troubleshooting
#    - Cross-account dashboard for multi-environment view
#    - Dynamic dashboards with Lambda for custom logic
#    - Dashboard sharing via URL for team collaboration

# 4. "What about cost?"
#    - First 3 dashboards: FREE
#    - Additional dashboards: $3/month each
#    - Pro tip: Combine multiple services in one dashboard to save cost

# 5. "Better alternatives?"
#    - Grafana: More features, prettier graphs, open-source
#    - Datadog: Enterprise monitoring, better APM
#    - New Relic: Application performance monitoring
#    - But CloudWatch is native AWS, no extra infrastructure needed!

# ============================================================================
# NEXT STEPS AFTER APPLYING THIS FILE
# ============================================================================

# 1. Run: terraform plan
#    - Review what will be created (1 SNS topic, 1 subscription, 3 alarms)

# 2. Run: terraform apply
#    - Terraform will create resources

# 3. Check your email inbox (and spam folder!)
#    - AWS will send "AWS Notification - Subscription Confirmation"
#    - Click "Confirm subscription" link

# 4. Verify in AWS Console:
#    - SNS: https://console.aws.amazon.com/sns/v3/home?region=eu-west-1#/topics
#    - CloudWatch Alarms: https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#alarmsV2:

# 5. Test an alarm (optional):
#    - SSH to EC2: ssh -i codedetect-key ec2-user@<IP>
#    - Run CPU stress test: stress --cpu 2 --timeout 360s
#    - Wait 5 minutes, check email for alarm

# ============================================================================
