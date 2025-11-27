# ============================================================================
# BILLING ALERTS - Cost Monitoring
# ============================================================================
# CloudWatch alarms to notify you when AWS costs exceed thresholds
# Helps prevent unexpected bills
# ============================================================================

# ----------------------------------------------------------------------------
# CLOUDWATCH BILLING ALARM - $10 Threshold
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "billing_alarm_10" {
  alarm_name          = "${local.name_prefix}-billing-alert-10-usd"
  alarm_description   = "Alert when estimated monthly charges exceed $10 USD"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = 10.0
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-billing-alert-10"
    }
  )
}

# ----------------------------------------------------------------------------
# CLOUDWATCH BILLING ALARM - $20 Threshold
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "billing_alarm_20" {
  alarm_name          = "${local.name_prefix}-billing-alert-20-usd"
  alarm_description   = "Alert when estimated monthly charges exceed $20 USD"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = 20.0
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-billing-alert-20"
    }
  )
}

# ----------------------------------------------------------------------------
# CLOUDWATCH BILLING ALARM - $50 Threshold (Emergency)
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "billing_alarm_50" {
  alarm_name          = "${local.name_prefix}-billing-alert-50-usd"
  alarm_description   = "EMERGENCY: Estimated monthly charges exceed $50 USD"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = 50.0
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-billing-alert-50-EMERGENCY"
    }
  )
}

# ============================================================================
# NOTES
# ============================================================================
#
# IMPORTANT: Billing metrics are ONLY available in us-east-1 region!
# - These alarms must be created in us-east-1 even if your resources are in eu-west-1
# - AWS Billing metrics are global and only published to us-east-1
#
# To enable billing alerts:
# 1. Go to AWS Console → Billing Dashboard
# 2. Click "Billing Preferences"
# 3. Enable "Receive Billing Alerts"
# 4. Save preferences
#
# Without this setting, billing metrics won't be published to CloudWatch!
#
# Expected Costs (with free tier):
# - Month 1-12: ~$16/month (ALB only, RDS free)
# - After 12 months: ~$56/month (ALB + EC2 + RDS)
#
# ============================================================================
