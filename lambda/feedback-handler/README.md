# Lambda Feedback Handler

## How It Works

### Architecture Flow
```
User fills feedback form on website
         ↓
Flask app publishes to SNS topic
(message contains: name, email, type, message)
         ↓
SNS triggers Lambda function
         ↓
Lambda formats HTML email
         ↓
Lambda sends via SES with Reply-To header
         ↓
You receive formatted email in Gmail
         ↓
You click "Reply" → Email goes directly to user
```

### Why Lambda + SES Instead of Direct SNS Email?

**Problem with SNS → Email:**
- Gmail marks as spam/bulk mail
- Emails bounce frequently
- Auto-unsubscribe after bounce
- Can't reply to users

**Solution with SNS → Lambda → SES:**
- ✅ Better email deliverability (SES reputation)
- ✅ Can reply directly to users (Reply-To header)
- ✅ Custom HTML formatting
- ✅ No bounce issues
- ✅ Professional-looking emails

### The Magic: Reply-To Header

When Lambda sends email via SES, it sets:
```python
ses.send_email(
    Source='noreply@codedetect.app',           # From address
    Destination={'ToAddresses': [your_email]}, # To you
    ReplyToAddresses=[user_email],             # KEY: Reply goes to user!
    ...
)
```

When you click "Reply" in Gmail:
- Gmail sees `Reply-To: user@example.com`
- Opens compose window with user's email pre-filled
- Your reply goes directly to the user (not to noreply@)

## Setup Steps

### 1. Verify Your Email in SES

SES starts in **Sandbox Mode** - can only send to verified emails.

```bash
# Verify your email
aws ses verify-email-identity \
  --email-address your-email@gmail.com \
  --region eu-west-1
```

Check your inbox for verification email from AWS and click the link.

### 2. Check Verification Status

```bash
aws ses list-verified-email-addresses --region eu-west-1
```

Should show your email in the list.

### 3. Deploy Lambda via Terraform

```bash
cd terraform
terraform plan
terraform apply
```

This creates:
- Lambda function
- IAM role with SES permissions
- SNS subscription (SNS → Lambda)
- CloudWatch log group

### 4. Test the Flow

```bash
# Publish test message to SNS
aws sns publish \
  --topic-arn arn:aws:sns:eu-west-1:YOUR_ACCOUNT:codedetect-prod-user-feedback \
  --message '{
    "name": "Test User",
    "email": "test@example.com",
    "type": "Bug Report",
    "message": "This is a test feedback message"
  }' \
  --region eu-west-1
```

You should receive an email within 10 seconds!

### 5. (Optional) Request Production Access

In sandbox mode, you can only send to verified emails. For production:

1. Go to SES Console → Account Dashboard
2. Click "Request production access"
3. Fill out form:
   - **Use case:** Transactional emails (user feedback system)
   - **Website URL:** Your CodeDetect URL
   - **Description:** Send feedback emails from users to support team
4. Usually approved within 24 hours

Once approved, you can send to ANY email address (not just verified ones).

## Message Format from Flask App

Your Flask app should publish this JSON to SNS:

```python
import boto3
import json

sns = boto3.client('sns', region_name='eu-west-1')

sns.publish(
    TopicArn='arn:aws:sns:eu-west-1:123456789:codedetect-prod-user-feedback',
    Message=json.dumps({
        'name': 'John Doe',
        'email': 'john@example.com',
        'type': 'Bug Report',
        'message': 'The upload button is not working...',
        'timestamp': '2024-01-15T10:30:00Z'
    })
)
```

## Troubleshooting

### Email not arriving?

Check Lambda logs:
```bash
aws logs tail /aws/lambda/codedetect-prod-feedback-handler --follow
```

### SES quota exceeded?

Check sending quota:
```bash
aws ses get-send-quota --region eu-west-1
```

Sandbox limits: 200 emails/day, 1 email/second

### Reply not working?

Make sure Lambda sets `ReplyToAddresses` - check the code in `lambda_function.py:145`

## Cost

- **Lambda:** Free tier = 1M requests/month (you'll use ~100/month = $0.00)
- **SES:** $0.10 per 1,000 emails (100 emails/month = $0.01)
- **Total:** ~$0.01/month

## Files

- `lambda_function.py` - Main Lambda code
- `../../terraform/lambda.tf` - Terraform config
- `../../terraform/sns.tf` - SNS topic (updated to use Lambda)
