#!/bin/bash
# ============================================================================
# SNS Subscription Diagnostic and Fix Script
# ============================================================================
# This script helps diagnose and fix SNS email subscription issues
#
# Usage: bash fix-sns-subscription.sh
# ============================================================================

set -e

echo "🔍 SNS Subscription Diagnostic Tool"
echo "===================================="
echo ""

# Get the SNS topic ARNs
FEEDBACK_TOPIC_ARN="arn:aws:sns:eu-west-1:772297676546:codedetect-user-feedback"
ALERTS_TOPIC_ARN=$(aws sns list-topics --region eu-west-1 --query "Topics[?contains(TopicArn, 'codedetect-alerts')].TopicArn" --output text)

echo "📋 Found Topics:"
echo "  Feedback Topic: $FEEDBACK_TOPIC_ARN"
echo "  Alerts Topic: $ALERTS_TOPIC_ARN"
echo ""

# Function to check subscription status
check_subscription() {
    local topic_arn=$1
    local topic_name=$2

    echo "-----------------------------------"
    echo "Checking: $topic_name"
    echo "ARN: $topic_arn"
    echo "-----------------------------------"

    # List all subscriptions for this topic
    subs=$(aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" --region eu-west-1 2>&1)

    if echo "$subs" | grep -q "NotFoundException"; then
        echo "❌ ERROR: Topic not found! You may need to create it."
        return 1
    fi

    # Check if any subscriptions exist
    sub_count=$(echo "$subs" | grep -c "SubscriptionArn" || true)

    if [ "$sub_count" -eq 0 ]; then
        echo "❌ No subscriptions found for this topic"
        echo "   You need to subscribe an email address"
        return 1
    fi

    # Show subscription status
    echo "$subs" | grep -E "(Endpoint|SubscriptionArn|Protocol)" || true

    # Check for pending confirmations
    if echo "$subs" | grep -q "PendingConfirmation"; then
        echo ""
        echo "⚠️  WARNING: Subscription is PENDING CONFIRMATION"
        echo "   Check your email for a confirmation message from AWS SNS"
        echo "   Click the 'Confirm subscription' link"
        echo "   Pending confirmations expire after 3 days"
        return 1
    fi

    # Check if subscription is confirmed
    if echo "$subs" | grep -q "arn:aws:sns:"; then
        echo ""
        echo "✅ Subscription is CONFIRMED and active"
        return 0
    fi

    echo ""
    return 1
}

# Check both topics
echo ""
echo "======================================"
echo "1. Checking FEEDBACK Topic (for Report Issue feature)"
echo "======================================"
check_subscription "$FEEDBACK_TOPIC_ARN" "User Feedback Topic"

echo ""
echo "======================================"
echo "2. Checking ALERTS Topic (for CloudWatch monitoring)"
echo "======================================"
if [ -n "$ALERTS_TOPIC_ARN" ]; then
    check_subscription "$ALERTS_TOPIC_ARN" "Monitoring Alerts Topic"
else
    echo "❌ Alerts topic not found - may not be created yet"
fi

echo ""
echo "======================================"
echo "🛠️  HOW TO FIX SUBSCRIPTION ISSUES"
echo "======================================"
echo ""
echo "OPTION 1: Subscribe to Feedback Topic (for app reports)"
echo "--------------------------------------------------------"
echo "Run this command to subscribe your email:"
echo ""
echo "aws sns subscribe \\"
echo "  --topic-arn $FEEDBACK_TOPIC_ARN \\"
echo "  --protocol email \\"
echo "  --notification-endpoint YOUR_EMAIL@example.com \\"
echo "  --region eu-west-1"
echo ""
echo "Then check your email and click 'Confirm subscription'"
echo ""

echo "OPTION 2: Re-confirm existing subscription"
echo "--------------------------------------------------------"
echo "If subscription shows 'PendingConfirmation':"
echo "  1. Check your spam/junk folder for AWS SNS confirmation email"
echo "  2. Click the 'Confirm subscription' link"
echo "  3. If email expired, delete and recreate subscription (see OPTION 1)"
echo ""

echo "OPTION 3: Test if subscription works"
echo "--------------------------------------------------------"
echo "Send a test message to verify email delivery:"
echo ""
echo "aws sns publish \\"
echo "  --topic-arn $FEEDBACK_TOPIC_ARN \\"
echo "  --subject 'Test Message' \\"
echo "  --message 'This is a test to verify SNS email delivery works' \\"
echo "  --region eu-west-1"
echo ""
echo "You should receive this email within 1 minute if subscription is active"
echo ""

echo "OPTION 4: Check if email is bouncing"
echo "--------------------------------------------------------"
echo "Emails might bounce if:"
echo "  - Email address is invalid"
echo "  - Your email server blocks AWS SNS"
echo "  - Email goes to spam and you mark it as spam"
echo ""
echo "To check bounce complaints:"
echo "aws sns get-topic-attributes --topic-arn $FEEDBACK_TOPIC_ARN --region eu-west-1"
echo ""

echo "======================================"
echo "📊 COMMON ISSUES & SOLUTIONS"
echo "======================================"
echo ""
echo "Issue: 'Subscription keeps disappearing'"
echo "  → AWS auto-unsubscribes bounced emails after multiple failures"
echo "  → Solution: Use a different email or whitelist sns@amazon.com"
echo ""
echo "Issue: 'Never received confirmation email'"
echo "  → Check spam folder"
echo "  → Check email filters"
echo "  → Try different email address"
echo ""
echo "Issue: 'Application says SNS_TOPIC_ARN not configured'"
echo "  → Set environment variable in your app:"
echo "  → export SNS_TOPIC_ARN='$FEEDBACK_TOPIC_ARN'"
echo ""

echo "======================================"
echo "Done! 🎉"
echo "======================================"
