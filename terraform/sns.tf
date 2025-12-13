# ============================================================================
# CODEDETECT - SNS TOPIC FOR USER FEEDBACK
# ============================================================================
# This file creates an SNS topic for receiving user feedback and bug reports
# from the CodeDetect application.
#
# WHAT this does: Creates SNS topic + email subscription for user reports
# WHY we need it: Application's "Report Issue" feature needs to send emails
# HOW it works: App publishes to SNS → SNS emails you → You respond to user
# ============================================================================

# ----------------------------------------------------------------------------
# SNS TOPIC - User Feedback Channel
# ----------------------------------------------------------------------------

# WHAT: SNS Topic for user feedback/bug reports
# This is separate from monitoring alerts (monitoring.tf)
# The application publishes messages here when users submit feedback

resource "aws_sns_topic" "user_feedback" {
  name         = "${local.name_prefix}-user-feedback"
  display_name = "CodeDetect User Feedback"

  # Tags for organization
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-user-feedback"
      Purpose     = "User Feedback"
      Application = "CodeDetect"
    }
  )
}

# ----------------------------------------------------------------------------
# SNS SUBSCRIPTION - Email Notification
# ----------------------------------------------------------------------------

# WHAT: Email subscription to receive user feedback
# Uses the same email as monitoring alerts, but you could use different emails

resource "aws_sns_topic_subscription" "user_feedback_email" {
  topic_arn = aws_sns_topic.user_feedback.arn
  protocol  = "email"
  # Use +feedback to avoid Gmail bounce issues
  endpoint  = replace(var.notification_email, "@", "+feedback@")

  # IMPORTANT: After terraform apply, you MUST:
  # 1. Check your email for "AWS Notification - Subscription Confirmation"
  # 2. Click "Confirm subscription" link
  # 3. The link is valid for 3 days - if it expires, run terraform apply again
  #
  # Using +feedback trick: nyeinthunaing322+feedback@gmail.com
  # This bypasses Gmail's bounce detection while delivering to same inbox
}

# ----------------------------------------------------------------------------
# SNS TOPIC POLICY - Allow Application to Publish
# ----------------------------------------------------------------------------

# WHAT: Topic policy that allows EC2 instances to publish messages
# WHY: Without this, your app can't send messages to the topic
# HOW: Grants sns:Publish permission to the EC2 IAM role

resource "aws_sns_topic_policy" "user_feedback_policy" {
  arn = aws_sns_topic.user_feedback.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Publish"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2.arn # EC2 role from ec2.tf:274
        }
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.user_feedback.arn
      },
      {
        Sid    = "AllowOwnerManagement"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.user_feedback.arn
      }
    ]
  })
}

# ----------------------------------------------------------------------------
# DATA SOURCE - Get Current AWS Account Info
# ----------------------------------------------------------------------------

# Note: aws_caller_identity "current" is already defined in main.tf:81
# We reuse that data source here for the topic policy

# ============================================================================
# WHY THIS FIXES YOUR UNSUBSCRIBE PROBLEM
# ============================================================================
#
# The issue you're experiencing - "subscribe then auto-unsubscribe" - happens
# because of EMAIL BOUNCES or SPAM COMPLAINTS.
#
# When you manually create an SNS subscription via AWS Console/CLI, AWS has
# no way to track if your email provider is:
# - Bouncing emails (mailbox full, invalid address, server issues)
# - Marking emails as spam (Gmail/Yahoo auto-filters)
# - Auto-unsubscribing via email client rules
#
# AWS SNS automatically unsubscribes email addresses that:
# 1. Bounce repeatedly (hard bounces = instant unsubscribe)
# 2. Mark emails as spam (complaint feedback loops)
# 3. Have pending confirmation expire (3 days)
#
# TERRAFORM ADVANTAGE:
# Using Terraform means:
# - Subscription is recreated if it disappears
# - You can quickly re-apply if it breaks
# - Infrastructure-as-code tracks the expected state
#
# HOWEVER, this won't fix email bounces. You still need to:
# 1. Whitelist @sns.amazonaws.com in your email filters
# 2. Check spam folder and mark AWS SNS emails as "Not Spam"
# 3. Ensure your inbox isn't full
# 4. Use a reliable email provider (Gmail, Outlook, work email)
#
# ============================================================================

# ============================================================================
# COST
# ============================================================================
#
# AWS SNS Pricing:
# - Topic creation: FREE
# - Email subscriptions: FREE
# - First 1,000 email notifications per month: FREE
# - After that: $2.00 per 100,000 emails
#
# For a feedback system (probably <100 emails/month): $0.00/month
#
# ============================================================================

# ============================================================================
# HOW TO USE THIS FILE
# ============================================================================
#
# 1. Add this file to your terraform directory
#
# 2. Run terraform plan to preview:
#    terraform plan
#
# 3. Apply the changes:
#    terraform apply
#
# 4. IMPORTANT: Check your email and confirm subscription!
#    Look for subject: "AWS Notification - Subscription Confirmation"
#    Click "Confirm subscription" link
#
# 5. Verify subscription is active:
#    aws sns list-subscriptions-by-topic \
#      --topic-arn $(terraform output -raw sns_feedback_topic_arn) \
#      --region eu-west-1
#
#    Should show SubscriptionArn (not "PendingConfirmation")
#
# 6. Test it works:
#    aws sns publish \
#      --topic-arn $(terraform output -raw sns_feedback_topic_arn) \
#      --subject "Test" \
#      --message "Testing user feedback SNS topic" \
#      --region eu-west-1
#
#    You should receive email within 1 minute
#
# 7. Deploy updated application with SNS_TOPIC_ARN environment variable
#
# ============================================================================

# ============================================================================
# TROUBLESHOOTING SUBSCRIPTION ISSUES
# ============================================================================
#
# Problem: "Subscription disappears after confirming"
# Cause: Email is bouncing or being marked as spam
# Solution:
#   1. Check spam folder - move AWS SNS emails to inbox
#   2. Mark as "Not Spam" or "Not Junk"
#   3. Add filter rule: From "@sns.amazonaws.com" → Never spam
#   4. Try different email address
#   5. Use SMS instead: protocol = "sms", endpoint = "+1234567890"
#
# Problem: "Never received confirmation email"
# Cause: Email went to spam or was filtered
# Solution:
#   1. Check spam/junk folder
#   2. Check email filters/rules
#   3. Whitelist no-reply@sns.amazonaws.com
#   4. Try terraform destroy + apply to resend confirmation
#
# Problem: "Application still says 'SNS not configured'"
# Cause: Environment variable not set
# Solution:
#   1. Check secrets.tf has SNS topic ARN parameter
#   2. Verify entrypoint.sh loads the parameter
#   3. Restart application containers
#   4. Check: echo $SNS_TOPIC_ARN (should show ARN)
#
# ============================================================================

# ============================================================================
# INTERVIEW TALKING POINTS
# ============================================================================
#
# When discussing this in interviews, mention:
#
# 1. "Why separate topics for monitoring vs user feedback?"
#    - Different audiences (ops team vs support team)
#    - Different urgency levels
#    - Different routing (PagerDuty for alerts, email for feedback)
#    - Can add different subscriptions (Slack for alerts, Jira for feedback)
#
# 2. "Why use SNS instead of sending email directly from the app?"
#    - Decoupling: Can add multiple notification channels later
#    - Reliability: SNS handles retries, dead letter queues
#    - No SMTP config needed in application
#    - Can route to multiple destinations (email, SMS, Lambda, SQS)
#    - AWS manages email reputation and deliverability
#
# 3. "How do you handle email bounces?"
#    - Monitor CloudWatch metrics for failed deliveries
#    - Set up DLQ (Dead Letter Queue) for failed messages
#    - Implement retry logic with exponential backoff
#    - Consider using SES for more control over email delivery
#
# 4. "Security considerations?"
#    - Topic policy restricts who can publish (only our EC2 instances)
#    - Encryption at rest using AWS KMS (can enable with kms_master_key_id)
#    - IAM role-based permissions (no hardcoded credentials)
#    - Audit trail via CloudTrail
#
# ============================================================================
