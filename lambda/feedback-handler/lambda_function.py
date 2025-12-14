"""
CodeDetect Feedback Email Handler
==================================
This Lambda function receives user feedback from SNS and sends formatted emails via SES.

WHAT: Processes SNS messages and sends emails with reply-to support
WHY: Allows you to reply directly to users from your inbox
HOW: SNS → Lambda → SES → Your Gmail (with user email as reply-to)
"""

import json
import boto3
import os
from datetime import datetime

# Initialize AWS clients
ses = boto3.client('ses', region_name='eu-west-1')
sns = boto3.client('sns', region_name='eu-west-1')

# Get environment variables
RECIPIENT_EMAIL = os.environ.get('RECIPIENT_EMAIL', 'your-email@example.com')
SOURCE_EMAIL = os.environ.get('SOURCE_EMAIL', 'noreply@your-domain.com')


def lambda_handler(event, context):
    """
    Main Lambda handler function

    Args:
        event: SNS event containing the feedback message
        context: Lambda context object

    Returns:
        dict: Response with status code and message
    """

    print(f"Received event: {json.dumps(event)}")

    try:
        # Parse SNS message
        sns_message = event['Records'][0]['Sns']
        message_body = json.loads(sns_message['Message'])

        # Extract feedback details
        user_name = message_body.get('name', 'Anonymous User')
        user_email = message_body.get('email', 'noreply@example.com')
        feedback_type = message_body.get('type', 'General Feedback')
        feedback_message = message_body.get('message', 'No message provided')
        timestamp = message_body.get('timestamp', datetime.utcnow().isoformat())

        # Format email subject
        subject = f"[CodeDetect Feedback] {feedback_type} from {user_name}"

        # Format email body (HTML)
        html_body = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: #232f3e; color: white; padding: 15px; border-radius: 5px; }}
                .content {{ background: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0; }}
                .footer {{ color: #666; font-size: 12px; margin-top: 20px; }}
                .label {{ font-weight: bold; color: #232f3e; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>📧 New Feedback from CodeDetect</h2>
                </div>

                <div class="content">
                    <p><span class="label">From:</span> {user_name} ({user_email})</p>
                    <p><span class="label">Type:</span> {feedback_type}</p>
                    <p><span class="label">Time:</span> {timestamp}</p>

                    <hr>

                    <h3>Message:</h3>
                    <p>{feedback_message}</p>
                </div>

                <div class="footer">
                    <p>💡 <strong>How to reply:</strong> Just hit "Reply" in your email client.
                    Your response will go directly to {user_email}</p>
                    <p>This email was sent via AWS Lambda + SES from your CodeDetect application.</p>
                </div>
            </div>
        </body>
        </html>
        """

        # Plain text version (fallback)
        text_body = f"""
New Feedback from CodeDetect
============================

From: {user_name} ({user_email})
Type: {feedback_type}
Time: {timestamp}

Message:
{feedback_message}

---
To reply: Just hit "Reply" in your email client.
Your response will go directly to {user_email}
        """

        # Send email via SES
        response = ses.send_email(
            Source=SOURCE_EMAIL,
            Destination={
                'ToAddresses': [RECIPIENT_EMAIL]
            },
            Message={
                'Subject': {
                    'Data': subject,
                    'Charset': 'UTF-8'
                },
                'Body': {
                    'Text': {
                        'Data': text_body,
                        'Charset': 'UTF-8'
                    },
                    'Html': {
                        'Data': html_body,
                        'Charset': 'UTF-8'
                    }
                }
            },
            ReplyToAddresses=[user_email]  # KEY: This lets you reply to the user!
        )

        print(f"Email sent successfully! Message ID: {response['MessageId']}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Feedback email sent successfully',
                'messageId': response['MessageId']
            })
        }

    except Exception as e:
        print(f"Error processing feedback: {str(e)}")

        # Send error notification
        try:
            ses.send_email(
                Source=SOURCE_EMAIL,
                Destination={'ToAddresses': [RECIPIENT_EMAIL]},
                Message={
                    'Subject': {'Data': '[CodeDetect] Feedback Processing Error'},
                    'Body': {
                        'Text': {
                            'Data': f"Failed to process feedback email.\n\nError: {str(e)}\n\nEvent: {json.dumps(event, indent=2)}"
                        }
                    }
                }
            )
        except:
            pass  # If error notification also fails, just log it

        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing feedback',
                'error': str(e)
            })
        }
