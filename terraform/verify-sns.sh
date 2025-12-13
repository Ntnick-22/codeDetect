#!/bin/bash
# Verify SNS subscription is confirmed

TOPIC_ARN=$(terraform output -raw sns_feedback_topic_arn)

echo "Checking SNS subscription for: $TOPIC_ARN"
echo ""

aws sns list-subscriptions-by-topic \
  --topic-arn "$TOPIC_ARN" \
  --region eu-west-1 \
  --query 'Subscriptions[0].[Endpoint,SubscriptionArn]' \
  --output table

echo ""
SUB_STATUS=$(aws sns list-subscriptions-by-topic \
  --topic-arn "$TOPIC_ARN" \
  --region eu-west-1 \
  --query 'Subscriptions[0].SubscriptionArn' \
  --output text)

if [ "$SUB_STATUS" = "PendingConfirmation" ]; then
  echo "❌ Status: PENDING - Check your email and confirm subscription!"
elif [ -z "$SUB_STATUS" ]; then
  echo "❌ Status: NO SUBSCRIPTION - Run terraform apply"
else
  echo "✅ Status: CONFIRMED"
  echo ""
  echo "Testing email delivery..."
  aws sns publish \
    --topic-arn "$TOPIC_ARN" \
    --subject "CodeDetect Test" \
    --message "Test email from CodeDetect SNS. If you received this, notifications are working!" \
    --region eu-west-1
  echo "✅ Test email sent! Check your inbox."
fi
