# ============================================================================
# CODEDETECT - SECRETS MANAGEMENT WITH AWS SYSTEMS MANAGER PARAMETER STORE
# ============================================================================
# This file manages application secrets securely using AWS SSM Parameter Store
#
# WHAT this does: Stores sensitive config (API keys, passwords) in AWS instead of code
# WHY we need it: Hardcoding secrets in code = MAJOR security vulnerability
# HOW it works: App fetches secrets from AWS at runtime using IAM permissions
#
# BENEFITS:
# - No secrets in git repository
# - Centralized secret management
# - Audit trail of who accessed what
# - Easy rotation without code changes
# - Free tier: 10,000 parameters (we use ~5)
# ============================================================================

# ----------------------------------------------------------------------------
# RANDOM SECRET GENERATOR - Flask Secret Key
# ----------------------------------------------------------------------------

# WHAT: Terraform random_password resource
# Generates a cryptographically secure random string
# This will be used as Flask's SECRET_KEY for session encryption

# WHY: Flask needs SECRET_KEY to:
# - Sign session cookies (prevent tampering)
# - Generate CSRF tokens
# - Encrypt sensitive data
# If you don't set this, Flask uses a weak default or fails in production

resource "random_password" "flask_secret" {
  length  = 64   # Long enough for strong security
  special = true # Include special characters (!@#$%)

  # Keepers ensure new secret is generated only when we want
  # If any of these values change, a new secret will be generated
  keepers = {
    environment = var.environment
  }
}

# ----------------------------------------------------------------------------
# SSM PARAMETER 1: Flask Secret Key
# ----------------------------------------------------------------------------

# WHAT: AWS Systems Manager Parameter Store - Secure String
# Stores the Flask secret key with encryption at rest

# SecureString vs String:
# - String: Plaintext (visible in console)
# - SecureString: Encrypted with AWS KMS (recommended for secrets)

resource "aws_ssm_parameter" "flask_secret" {
  name        = "/${local.app_name}/${var.environment}/flask/secret_key"
  description = "Flask application secret key for session encryption"
  type        = "SecureString" # Encrypted storage
  value       = random_password.flask_secret.result

  # Tags for organization
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-flask-secret"
      Type        = "Secret"
      Application = "Flask"
      Sensitive   = "true"
    }
  )
}

# ----------------------------------------------------------------------------
# SSM PARAMETER 2: S3 Bucket Name
# ----------------------------------------------------------------------------

# WHAT: Store S3 bucket name in Parameter Store
# WHY: So application doesn't need hardcoded bucket name

# "But bucket name isn't secret!" - True, but storing it here means:
# 1. Single source of truth for all config (secret or not)
# 2. Easy to change without code deployment
# 3. Consistent pattern for all app config

resource "aws_ssm_parameter" "s3_bucket" {
  name        = "/${local.app_name}/${var.environment}/s3/bucket_name"
  description = "S3 bucket name for file uploads"
  type        = "String"                 # Not secret, so no encryption needed
  value       = aws_s3_bucket.uploads.id # Reference from s3.tf

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-s3-bucket-param"
      Type        = "Config"
      Application = "Storage"
    }
  )
}

# ----------------------------------------------------------------------------
# SSM PARAMETER 3: Database URL
# ----------------------------------------------------------------------------

# WHAT: Database connection string
# Currently SQLite, but when you migrate to RDS this becomes critical

# Example future values:
# SQLite: sqlite:////app/instance/codedetect.db
# PostgreSQL: postgresql://user:pass@hostname:5432/dbname
# MySQL: mysql://user:pass@hostname:3306/dbname

resource "aws_ssm_parameter" "database_url" {
  name        = "/${local.app_name}/${var.environment}/database/url"
  description = "Database connection URL"
  type        = "SecureString"

  # Use RDS PostgreSQL if enabled, otherwise fallback to SQLite
  value = var.use_rds ? "postgresql://${var.db_username}:${nonsensitive(var.db_password)}@${aws_db_instance.postgres[0].address}:${aws_db_instance.postgres[0].port}/${var.db_name}" : "sqlite:////app/instance/codedetect.db"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-db-url-param"
      Type        = "Config"
      Application = "Database"
      Sensitive   = "true"
    }
  )
}

# ----------------------------------------------------------------------------
# SSM PARAMETER 4: Application Environment
# ----------------------------------------------------------------------------

# WHAT: Tells application what mode to run in
# WHY: Changes behavior (debug mode, logging level, etc.)

resource "aws_ssm_parameter" "flask_env" {
  name        = "/${local.app_name}/${var.environment}/flask/env"
  description = "Flask application environment (production/development)"
  type        = "String"
  value       = var.environment # Uses environment from variables.tf

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-flask-env-param"
      Type        = "Config"
      Application = "Flask"
    }
  )
}

# ----------------------------------------------------------------------------
# PARAMETER NAMING CONVENTION
# ----------------------------------------------------------------------------

# We use hierarchical naming:
# /<project>/<environment>/<component>/<parameter>
#
# Examples:
# /codedetect/prod/flask/secret_key
# /codedetect/prod/s3/bucket_name
# /codedetect/prod/database/url
#
# Benefits:
# - Easy to find related parameters
# - Can grant permissions by path (e.g., /codedetect/prod/*)
# - Clear ownership (which app/component uses what)
# - Supports multiple environments (prod, dev, staging)

# ----------------------------------------------------------------------------
# HOW THE APPLICATION WILL USE THESE
# ----------------------------------------------------------------------------

# The EC2 instance will:
# 1. Have IAM role with ssm:GetParameter permission
# 2. On container startup, fetch parameters using AWS SDK
# 3. Inject them as environment variables
# 4. Flask app reads from environment variables (already does this!)

# Python code example (we'll add this to app.py):
# ```python
# import boto3
#
# def get_parameter(name):
#     ssm = boto3.client('ssm', region_name='eu-west-1')
#     response = ssm.get_parameter(Name=name, WithDecryption=True)
#     return response['Parameter']['Value']
#
# # At app startup:
# os.environ['FLASK_SECRET_KEY'] = get_parameter('/codedetect/prod/flask/secret_key')
# os.environ['S3_BUCKET_NAME'] = get_parameter('/codedetect/prod/s3/bucket_name')
# ```

# ----------------------------------------------------------------------------
# SECURITY NOTES
# ----------------------------------------------------------------------------

# ✅ GOOD PRACTICES IN THIS FILE:
# - Using SecureString for sensitive data (encrypted at rest)
# - Hierarchical naming for easy permission management
# - Generated secrets (not hardcoded)
# - Proper tagging for audit
# - No secrets in git (Terraform state has them, but state should be remote & encrypted)

# ❌ IMPORTANT: Terraform State Security
# - Terraform state file will contain the secret values in PLAINTEXT
# - For production: Use remote state backend with encryption (S3 + KMS)
# - Never commit terraform.tfstate to git
# - Add to .gitignore: *.tfstate, *.tfstate.backup

# 🔐 INTERVIEW TALKING POINT:
# "I use AWS Parameter Store for secrets management with encrypted storage.
# The application uses IAM roles to fetch secrets at runtime, so no credentials
# are hardcoded. For production, I'd also implement secret rotation using Lambda
# and move Terraform state to encrypted S3 backend."

# ----------------------------------------------------------------------------
# COST
# ----------------------------------------------------------------------------

# AWS Systems Manager Parameter Store pricing:
# - Standard parameters: FREE (up to 10,000 parameters)
# - SecureString: FREE (uses default AWS KMS key)
# - API calls: First 1 million calls/month = FREE
#
# Total cost for this setup: $0.00/month 🎉

# ----------------------------------------------------------------------------
# SSM PARAMETER 5: SNS Topic ARN for User Feedback
# ----------------------------------------------------------------------------

# WHAT: SNS topic ARN for user feedback/bug reports
# WHY: Application needs this to publish feedback messages
# The app reads this from environment variable: SNS_TOPIC_ARN

resource "aws_ssm_parameter" "sns_feedback_topic_arn" {
  name        = "${local.app_name}-${var.environment}-sns-feedback-topic-arn"
  description = "SNS Topic ARN for user feedback and bug reports"
  type        = "String"
  value       = aws_sns_topic.user_feedback.arn # From sns.tf
  overwrite   = true                            # Allow updating existing parameter

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-sns-feedback-arn"
      Type        = "Config"
      Application = "SNS"
    }
  )
}

# ----------------------------------------------------------------------------
# NEXT STEPS AFTER APPLYING
# ----------------------------------------------------------------------------

# 1. Apply Terraform:
#    terraform plan
#    terraform apply
#
# 2. Verify in AWS Console:
#    https://console.aws.amazon.com/systems-manager/parameters?region=eu-west-1
#
# 3. Test fetching a parameter:
#    aws ssm get-parameter --name "/codedetect/prod/flask/secret_key" --with-decryption
#
# 4. Update application code to fetch parameters (next todo)
# ============================================================================
