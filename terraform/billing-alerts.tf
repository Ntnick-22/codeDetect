# ============================================================================
# BILLING ALERTS - Cost Monitoring
# ============================================================================
# CloudWatch alarms to notify you when AWS costs exceed thresholds
# Helps prevent unexpected bills
# ============================================================================



resource "aws_cloudwatch_metric_alarm" "billing_alarm_30" {
  alarm_name          = "${local.name_prefix}-billing-alert-30-usd"
  alarm_description   = "Alert when estimated monthly charges exceed $30 USD (above expected $16-20/month)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = 30.0  # Trigger when costs exceed normal range
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-billing-alert-30"
    }
  )
}


