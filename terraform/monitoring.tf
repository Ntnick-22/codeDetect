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

# SMS Alerts (backup notification method)
resource "aws_sns_topic_subscription" "sms_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "sms"
  endpoint  = "+3530892131693" # Ireland phone number (with 0)

  # SMS will be sent immediately, no confirmation needed
  # Cost: ~$0.007 per SMS in EU
}

# ----------------------------------------------------------------------------
# Note: CPU alarms for Blue/Green ASGs are defined in loadbalancer.tf
# They trigger autoscaling policies AND send SNS notifications
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# CLOUDWATCH ALARM 1: Instance Status Check Failed
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

  # UPDATED: Now monitors Active Auto Scaling Group (blue or green)
  dimensions = {
    AutoScalingGroupName = local.active_asg_name
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

  # UPDATED: Now monitors Active Auto Scaling Group (blue or green)
  dimensions = {
    AutoScalingGroupName = local.active_asg_name
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

# ============================================================================
# CLOUDWATCH DASHBOARD - Production Monitoring
# ============================================================================
# Complete monitoring dashboard for Auto Scaling Group, ALB, and EFS
# Replaces Grafana with native CloudWatch visualization

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-monitoring"

  # Dashboard body is JSON defining layout and widgets
  dashboard_body = jsonencode({
    # Dashboard widgets are arranged in a grid (24 units wide)
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
          markdown = "# 📊 CodeDetect Production Monitoring\n**Active Environment:** ${var.active_environment} | **Auto Scaling Group:** ${local.active_asg_name} | **Load Balancer:** ${aws_lb.main.dns_name}\n**Region:** ${var.aws_region} | **EFS:** ${aws_efs_file_system.main.id} | **Database:** Shared on EFS | **Instances:** 2-4"
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
            aws_cloudwatch_metric_alarm.instance_status_check.arn,
            aws_cloudwatch_metric_alarm.high_network_out.arn,
            aws_cloudwatch_metric_alarm.blue_cpu_high.arn,
            aws_cloudwatch_metric_alarm.blue_cpu_low.arn,
            aws_cloudwatch_metric_alarm.green_cpu_high.arn,
            aws_cloudwatch_metric_alarm.green_cpu_low.arn
          ]
        }
      },

      # ===================================================================
      # ROW 2: AUTO SCALING GROUP - CPU & INSTANCE COUNT
      # ===================================================================

      # Widget 3: ASG CPU Utilization Graph
      {
        type   = "metric"
        x      = 0
        y      = 4
        width  = 12
        height = 6
        properties = {
          title  = "Auto Scaling Group - CPU Utilization"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", local.active_asg_name, { stat = "Average", label = "Average CPU", color = "#1f77b4" }],
            ["...", { stat = "Maximum", label = "Max CPU", color = "#ff7f0e" }],
            ["...", { stat = "Minimum", label = "Min CPU", color = "#2ca02c" }]
          ]
          period = 300
          stat   = "Average"
          yAxis = {
            left = {
              min   = 0
              max   = 100
              label = "Percentage"
            }
          }
          annotations = {
            horizontal = [
              {
                value = 80
                label = "High CPU Alarm"
                color = "#d62728"
              },
              {
                value = 70
                label = "Scale Up Threshold"
                color = "#ff7f0e"
              },
              {
                value = 30
                label = "Scale Down Threshold"
                color = "#2ca02c"
              }
            ]
          }
        }
      },

      # Widget 4: Instance Count
      {
        type   = "metric"
        x      = 12
        y      = 4
        width  = 6
        height = 6
        properties = {
          title  = "Active Instances"
          region = var.aws_region
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", local.active_asg_name, { stat = "Average", label = "Desired", color = "#1f77b4" }],
            [".", "GroupInServiceInstances", ".", ".", { stat = "Average", label = "In Service", color = "#2ca02c" }],
            [".", "GroupMinSize", ".", ".", { stat = "Average", label = "Min", color = "#ff7f0e" }],
            [".", "GroupMaxSize", ".", ".", { stat = "Average", label = "Max", color = "#d62728" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = {
              min = 0
              max = 5
            }
          }
        }
      },

      # Widget 5: Current CPU (Single Value)
      {
        type   = "metric"
        x      = 18
        y      = 4
        width  = 6
        height = 3
        properties = {
          title  = "Current Avg CPU"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", local.active_asg_name, { stat = "Average" }]
          ]
          period               = 60
          stat                 = "Average"
          view                 = "singleValue"
          setPeriodToTimeRange = true
        }
      },

      # Widget 6: Peak CPU (Single Value)
      {
        type   = "metric"
        x      = 18
        y      = 7
        width  = 6
        height = 3
        properties = {
          title  = "Peak CPU (1h)"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", local.active_asg_name, { stat = "Maximum" }]
          ]
          period = 3600
          stat   = "Maximum"
          view   = "singleValue"
        }
      },

      # ===================================================================
      # ROW 3: APPLICATION LOAD BALANCER METRICS
      # ===================================================================

      # Widget 7: ALB Request Count & Response Time
      {
        type   = "metric"
        x      = 0
        y      = 10
        width  = 12
        height = 6
        properties = {
          title  = "Load Balancer - Requests & Latency"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Sum", label = "Requests", yAxis = "left", color = "#1f77b4" }],
            [".", "TargetResponseTime", ".", ".", { stat = "Average", label = "Response Time (ms)", yAxis = "right", color = "#ff7f0e" }]
          ]
          period = 300
          yAxis = {
            left = {
              label = "Requests"
              min   = 0
            }
            right = {
              label = "Milliseconds"
              min   = 0
            }
          }
        }
      },

      # Widget 8: ALB HTTP Response Codes
      {
        type   = "metric"
        x      = 12
        y      = 10
        width  = 12
        height = 6
        properties = {
          title  = "Load Balancer - HTTP Response Codes"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Sum", label = "2XX (Success)", color = "#2ca02c" }],
            [".", "HTTPCode_Target_3XX_Count", ".", ".", { stat = "Sum", label = "3XX (Redirect)", color = "#1f77b4" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4XX (Client Error)", color = "#ff7f0e" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5XX (Server Error)", color = "#d62728" }]
          ]
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },

      # ===================================================================
      # ROW 4: TARGET HEALTH & CONNECTION METRICS
      # ===================================================================

      # Widget 9: Healthy/Unhealthy Targets
      {
        type   = "metric"
        x      = 0
        y      = 16
        width  = 8
        height = 6
        properties = {
          title  = "Target Health"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", replace(aws_lb_target_group.blue.arn, "/^.*:(targetgroup\\/.*)/", "$1"), "LoadBalancer", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Average", label = "Blue Healthy", color = "#2ca02c" }],
            [".", "UnHealthyHostCount", ".", replace(aws_lb_target_group.blue.arn, "/^.*:(targetgroup\\/.*)/", "$1"), ".", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Average", label = "Blue Unhealthy", color = "#d62728" }],
            [".", "HealthyHostCount", ".", replace(aws_lb_target_group.green.arn, "/^.*:(targetgroup\\/.*)/", "$1"), ".", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Average", label = "Green Healthy", color = "#1f77b4" }],
            [".", "UnHealthyHostCount", ".", replace(aws_lb_target_group.green.arn, "/^.*:(targetgroup\\/.*)/", "$1"), ".", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Average", label = "Green Unhealthy", color = "#ff7f0e" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = {
              min = 0
              max = 4
            }
          }
        }
      },

      # Widget 10: ALB Connection Count
      {
        type   = "metric"
        x      = 8
        y      = 16
        width  = 8
        height = 6
        properties = {
          title  = "Active Connections"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Sum", label = "Active Connections", color = "#1f77b4" }],
            [".", "NewConnectionCount", ".", ".", { stat = "Sum", label = "New Connections", color = "#2ca02c" }]
          ]
          period = 300
          stat   = "Sum"
        }
      },

      # Widget 11: Processed Bytes
      {
        type   = "metric"
        x      = 16
        y      = 16
        width  = 8
        height = 6
        properties = {
          title  = "Data Transfer"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "ProcessedBytes", "LoadBalancer", replace(aws_lb.main.arn, "/^.*:loadbalancer\\//", ""), { stat = "Sum", label = "Processed Bytes", color = "#1f77b4" }]
          ]
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              label = "Bytes"
              min   = 0
            }
          }
        }
      },

      # ===================================================================
      # ROW 5: NETWORK METRICS (EC2)
      # ===================================================================

      # Widget 12: Network In/Out
      {
        type   = "metric"
        x      = 0
        y      = 22
        width  = 12
        height = 6
        properties = {
          title  = "EC2 Network Traffic"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", local.active_asg_name, { stat = "Sum", label = "Network In", color = "#2ca02c" }],
            [".", "NetworkOut", ".", ".", { stat = "Sum", label = "Network Out", color = "#d62728" }]
          ]
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              label = "Bytes"
              min   = 0
            }
          }
        }
      },

      # Widget 13: Network Packets
      {
        type   = "metric"
        x      = 12
        y      = 22
        width  = 12
        height = 6
        properties = {
          title  = "EC2 Network Packets"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkPacketsIn", "AutoScalingGroupName", local.active_asg_name, { stat = "Sum", label = "Packets In", color = "#2ca02c" }],
            [".", "NetworkPacketsOut", ".", ".", { stat = "Sum", label = "Packets Out", color = "#d62728" }]
          ]
          period = 300
          stat   = "Sum"
        }
      },

      # ===================================================================
      # ROW 6: EFS METRICS
      # ===================================================================

      # Widget 14: EFS Data Transfer
      {
        type   = "metric"
        x      = 0
        y      = 28
        width  = 12
        height = 6
        properties = {
          title  = "EFS - Data Transfer (Shared Database & Uploads)"
          region = var.aws_region
          metrics = [
            ["AWS/EFS", "DataReadIOBytes", "FileSystemId", aws_efs_file_system.main.id, { stat = "Sum", label = "Read Bytes", color = "#2ca02c" }],
            [".", "DataWriteIOBytes", ".", ".", { stat = "Sum", label = "Write Bytes", color = "#1f77b4" }]
          ]
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              label = "Bytes"
              min   = 0
            }
          }
        }
      },

      # Widget 15: EFS Connection Count
      {
        type   = "metric"
        x      = 12
        y      = 28
        width  = 12
        height = 6
        properties = {
          title  = "EFS - Active Connections"
          region = var.aws_region
          metrics = [
            ["AWS/EFS", "ClientConnections", "FileSystemId", aws_efs_file_system.main.id, { stat = "Sum", label = "Active Connections", color = "#1f77b4" }]
          ]
          period = 60
          stat   = "Sum"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })
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
