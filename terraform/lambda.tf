# ============================================================================
# CODEDETECT - LAMBDA FUNCTION FOR FEEDBACK EMAIL HANDLING
# ============================================================================
# This Lambda function receives feedback from SNS and sends formatted emails via SES
# Allows you to reply directly to users from your inbox
# ============================================================================

# ----------------------------------------------------------------------------
# ARCHIVE LAMBDA CODE
# ----------------------------------------------------------------------------

# Create ZIP file of Lambda function code
data "archive_file" "feedback_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/feedback-handler/lambda_function.py"
  output_path = "${path.module}/../lambda/feedback-handler/lambda_function.zip"
}

# ----------------------------------------------------------------------------
# LAMBDA FUNCTION
# ----------------------------------------------------------------------------

resource "aws_lambda_function" "feedback_handler" {
  filename         = data.archive_file.feedback_lambda.output_path
  function_name    = "${local.name_prefix}-feedback-handler"
  role            = aws_iam_role.lambda_feedback.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.feedback_lambda.output_base64sha256
  runtime         = "python3.12"
  timeout         = 30

  environment {
    variables = {
      RECIPIENT_EMAIL = var.notification_email
      SOURCE_EMAIL    = "noreply@codedetect.app"  # Change to your verified SES domain
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-feedback-handler"
      Purpose = "Process user feedback and send emails"
    }
  )
}

# ----------------------------------------------------------------------------
# IAM ROLE FOR LAMBDA
# ----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_feedback" {
  name = "${local.name_prefix}-lambda-feedback-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-lambda-feedback-role"
    }
  )
}

# ----------------------------------------------------------------------------
# IAM POLICY - CloudWatch Logs
# ----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_feedback.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ----------------------------------------------------------------------------
# IAM POLICY - SES Send Email
# ----------------------------------------------------------------------------

resource "aws_iam_role_policy" "lambda_ses" {
  name = "${local.name_prefix}-lambda-ses-policy"
  role = aws_iam_role.lambda_feedback.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# ----------------------------------------------------------------------------
# SNS TOPIC SUBSCRIPTION - Trigger Lambda
# ----------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "feedback_lambda" {
  topic_arn = aws_sns_topic.user_feedback.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.feedback_handler.arn
}

# ----------------------------------------------------------------------------
# LAMBDA PERMISSION - Allow SNS to Invoke
# ----------------------------------------------------------------------------

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.feedback_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_feedback.arn
}

# ----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "feedback_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.feedback_handler.function_name}"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-feedback-lambda-logs"
    }
  )
}

# ============================================================================
# HOW THIS WORKS
# ============================================================================
#
# 1. User submits feedback on your website
# 2. Flask app publishes message to SNS topic (with user email, name, message)
# 3. SNS triggers Lambda function
# 4. Lambda formats a nice HTML email
# 5. Lambda sends email via SES with:
#    - To: Your email (notification_email)
#    - From: noreply@codedetect.app
#    - Reply-To: User's email
# 6. You receive email in Gmail
# 7. You hit "Reply" → Gmail sends directly to user's email
#
# ============================================================================

# ============================================================================
# SETUP STEPS
# ============================================================================
#
# 1. Verify your email in SES (required for sandbox mode):
#    aws ses verify-email-identity --email-address your-email@example.com --region eu-west-1
#
# 2. Check your email for verification link and confirm
#
# 3. (Optional) Request production access:
#    - Go to SES console → Account Dashboard → Request production access
#    - Fill out form explaining your use case
#    - Usually approved within 24 hours
#    - In sandbox: Can only send to verified emails
#    - In production: Can send to anyone
#
# 4. Update SOURCE_EMAIL in Lambda environment to match verified domain
#    - If you have domain: noreply@yourdomain.com
#    - Otherwise use: your-email@gmail.com (verify it in SES)
#
# 5. Apply Terraform:
#    terraform apply
#
# 6. Test by publishing to SNS:
#    aws sns publish --topic-arn $(terraform output -raw sns_feedback_topic_arn) \
#      --message '{"name":"Test User","email":"test@example.com","type":"Bug Report","message":"This is a test"}' \
#      --region eu-west-1
#
# ============================================================================
