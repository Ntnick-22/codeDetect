#!/bin/bash
# Test user feedback notification

ALB_DNS="codedetect-prod-alb-111225767.eu-west-1.elb.amazonaws.com"

echo "Testing user feedback notification..."
echo ""

# Send test feedback via API
curl -X POST http://$ALB_DNS/api/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "type": "bug",
    "message": "This is a test feedback message to verify SNS email notifications are working!"
  }'

echo ""
echo ""
echo "✅ Feedback sent!"
echo ""
echo "Check your Gmail inbox: nyeinthunaing322@gmail.com"
echo "You should receive an email with the feedback details within 1 minute."
echo ""
