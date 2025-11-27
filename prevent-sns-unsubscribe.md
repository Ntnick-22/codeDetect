# How to Fix SNS Auto-Unsubscribe Issue

## The Problem
You subscribe to SNS email notifications, but within seconds it automatically unsubscribes you.

## Root Causes

### 1. **Email Provider Feedback Loop**
Gmail, Yahoo, and other email providers have "feedback loops" that automatically report emails as spam:
- If AWS SNS emails go to your spam folder
- If you previously marked an SNS email as spam
- If your email filter rules block SNS emails

**Solution:**
1. Whitelist these email addresses in your email provider:
   - `no-reply@sns.amazonaws.com`
   - `@sns.amazonaws.com`

2. For Gmail:
   - Go to Settings → Filters and Blocked Addresses
   - Create a new filter: "From: @sns.amazonaws.com"
   - Action: Never send to Spam, Mark as important

3. Check your spam folder and mark any AWS SNS emails as "Not Spam"

### 2. **Email Bounce Issues**
AWS automatically unsubscribes emails that bounce repeatedly.

**Check if your email bounced:**
```bash
# Check recent bounce complaints
aws ses get-account-sending-enabled --region eu-west-1

# If you have SES configured, check bounce list
aws sesv2 list-suppressed-destinations --region eu-west-1
```

**Solution:**
- Use a different email address (work email, personal Gmail, etc.)
- Ensure your email inbox isn't full
- Check your email server isn't blocking AWS

### 3. **SNS Topic Policy Issues**
Sometimes the topic policy prevents subscriptions.

**Check current policy:**
```bash
aws sns get-topic-attributes \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --region eu-west-1 \
  --query 'Attributes.Policy'
```

### 4. **Complaint Feedback from Email Provider**
Your email provider might be auto-reporting SNS emails as complaints.

**Check CloudWatch for complaints:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/SNS \
  --metric-name NumberOfNotificationsFailedToRedrive \
  --dimensions Name=TopicName,Value=codedetect-user-feedback \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --region eu-west-1
```

## Recommended Solutions

### Option 1: Use a Different Email Address
The easiest solution - use a different email that doesn't have filters/blocks:

```bash
# Subscribe with new email
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --protocol email \
  --notification-endpoint NEW_EMAIL@example.com \
  --region eu-west-1

# Check confirmation
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --region eu-west-1
```

### Option 2: Use SMS Instead of Email
SNS supports SMS notifications:

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --protocol sms \
  --notification-endpoint +1234567890 \
  --region eu-west-1
```

### Option 3: Enable Email Feedback Forwarding
Configure SNS to use a verified SES email (more reliable):

1. Verify your email in SES:
```bash
aws ses verify-email-identity \
  --email-address nyeinthunaing322@gmail.com \
  --region eu-west-1
```

2. Update your application to use SES directly instead of SNS (more reliable for emails)

### Option 4: Check Email Filter Rules

**For Gmail:**
1. Go to https://mail.google.com/mail/u/0/#settings/filters
2. Look for any filters that might be blocking AWS SNS
3. Delete or modify filters that auto-delete/spam AWS emails

**For Outlook/Hotmail:**
1. Settings → Mail → Junk email
2. Add `@sns.amazonaws.com` to Safe Senders

**For Yahoo:**
1. Settings → More Settings → Filters
2. Check for filters blocking AWS emails

### Option 5: Set Up SNS Subscription with Confirmation Bypass (Enterprise only)
If you have AWS Enterprise Support, you can request subscription confirmation bypass.

## Immediate Fix - Step by Step

1. **First, unsubscribe the current broken subscription:**
```bash
# Get subscription ARN
SUB_ARN=$(aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --region eu-west-1 \
  --query 'Subscriptions[0].SubscriptionArn' \
  --output text)

# Unsubscribe
aws sns unsubscribe \
  --subscription-arn "$SUB_ARN" \
  --region eu-west-1
```

2. **Whitelist AWS SNS emails in Gmail:**
   - Open Gmail Settings
   - Filters and Blocked Addresses → Create new filter
   - From: `no-reply@sns.amazonaws.com`
   - Actions: ✓ Never send it to Spam, ✓ Always mark it as important
   - Create filter

3. **Check your spam folder and mark any AWS SNS emails as "Not Spam"**

4. **Subscribe again:**
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --protocol email \
  --notification-endpoint nyeinthunaing322@gmail.com \
  --region eu-west-1
```

5. **Immediately check your email (including spam) and confirm the subscription**

6. **Verify it's confirmed:**
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --region eu-west-1 \
  --query 'Subscriptions[*].[Endpoint,SubscriptionArn]' \
  --output table
```

Should show an ARN (not "PendingConfirmation")

7. **Test it:**
```bash
aws sns publish \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --subject "Test - SNS Working" \
  --message "If you receive this, your subscription is working!" \
  --region eu-west-1
```

## Alternative: Use CloudWatch Logs Instead

If email keeps failing, you can log reports to CloudWatch instead:

See `backend/app.py:394` - modify the `/api/report` endpoint to also log to CloudWatch:

```python
import logging
logger = logging.getLogger('codedetect-reports')

@app.route('/api/report', methods=['POST'])
def submit_report():
    # ... existing code ...

    # Also log to CloudWatch (backup if SNS fails)
    logger.info(f"Report received: {report_type} from {email} - {message}")

    # ... rest of code ...
```

Then view reports in CloudWatch Logs console.

## Debug Commands

```bash
# Check subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --region eu-west-1

# Check for bounces/complaints in the last 7 days
aws cloudwatch get-metric-statistics \
  --namespace AWS/SNS \
  --metric-name NumberOfNotificationsFailed \
  --dimensions Name=TopicName,Value=codedetect-user-feedback \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --region eu-west-1

# View topic attributes
aws sns get-topic-attributes \
  --topic-arn arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback \
  --region eu-west-1
```

## Contact AWS Support

If the issue persists after trying all solutions:
1. Open AWS Support case
2. Select "SNS" as the service
3. Describe: "Email subscription auto-unsubscribes immediately after confirmation"
4. Provide: Topic ARN, email address, subscription ARN
