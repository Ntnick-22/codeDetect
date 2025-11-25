#!/bin/bash
# ============================================================================
# CODEDETECT - DOCKER ENTRYPOINT SCRIPT
# ============================================================================
# This script runs when the Docker container starts
# It fetches secrets from AWS Parameter Store and starts the application
#
# WHAT: Container startup script with secrets management
# WHY: Fetch secrets at runtime (not baked into image)
# HOW: AWS SDK + IAM role permissions
# ============================================================================

set -e  # Exit on any error

echo "🚀 CodeDetect Container Starting..."
echo "📅 $(date)"

# ----------------------------------------------------------------------------
# FUNCTION: Fetch Parameter from SSM
# ----------------------------------------------------------------------------

# WHAT: Helper function to fetch a single parameter from Parameter Store
# INPUT: $1 = parameter name (e.g., /codedetect/prod/flask/secret_key)
# OUTPUT: Parameter value (decrypted if SecureString)
# ERROR: Returns empty string if parameter doesn't exist

get_parameter() {
    local param_name=$1
    local region=${AWS_REGION:-eu-west-1}

    echo "🔑 Fetching parameter: $param_name" >&2

    # Use AWS CLI to fetch parameter
    # --with-decryption: Decrypt SecureString parameters
    # --query: Extract just the value
    # --output text: Return plain text (not JSON)
    local value=$(aws ssm get-parameter \
        --name "$param_name" \
        --with-decryption \
        --region "$region" \
        --query 'Parameter.Value' \
        --output text 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$value" ]; then
        echo "   ✅ Successfully fetched $param_name" >&2
        echo "$value"  # Output ONLY the value to stdout
    else
        echo "   ⚠️  Failed to fetch $param_name - using default/env value" >&2
        echo ""  # Return empty string
    fi
}

# ----------------------------------------------------------------------------
# ENVIRONMENT DETECTION
# ----------------------------------------------------------------------------

# Determine environment (production, development, staging)
# Default to 'prod' if not set
APP_ENV=${ENVIRONMENT:-prod}
PROJECT_NAME=${PROJECT_NAME:-codedetect}
AWS_REGION=${AWS_REGION:-eu-west-1}

echo "🌍 Environment: $APP_ENV"
echo "📦 Project: $PROJECT_NAME"
echo "🗺️  Region: $AWS_REGION"

# ----------------------------------------------------------------------------
# FETCH SECRETS FROM PARAMETER STORE
# ----------------------------------------------------------------------------

echo ""
echo "🔐 Fetching secrets from AWS Parameter Store..."

# Check if we're running in AWS (has IAM role)
# If not, skip Parameter Store and use environment variables
if aws sts get-caller-identity &>/dev/null; then
    echo "✅ AWS credentials detected (IAM role)"

    # Fetch Flask secret key
    FLASK_SECRET_KEY=$(get_parameter "/$PROJECT_NAME/$APP_ENV/flask/secret_key")
    if [ -n "$FLASK_SECRET_KEY" ]; then
        export SECRET_KEY="$FLASK_SECRET_KEY"
    fi

    # Fetch S3 bucket name
    S3_BUCKET=$(get_parameter "/$PROJECT_NAME/$APP_ENV/s3/bucket_name")
    if [ -n "$S3_BUCKET" ]; then
        export S3_BUCKET_NAME="$S3_BUCKET"
    fi

    # Fetch database URL
    DB_URL=$(get_parameter "/$PROJECT_NAME/$APP_ENV/database/url")
    if [ -n "$DB_URL" ]; then
        export DATABASE_URL="$DB_URL"
    fi

    # Fetch Flask environment
    FLASK_ENVIRONMENT=$(get_parameter "/$PROJECT_NAME/$APP_ENV/flask/env")
    if [ -n "$FLASK_ENVIRONMENT" ]; then
        export FLASK_ENV="$FLASK_ENVIRONMENT"
    fi

    # Fetch SNS Topic ARN for user feedback
    SNS_ARN=$(get_parameter "$PROJECT_NAME-$APP_ENV-sns-feedback-topic-arn")
    if [ -n "$SNS_ARN" ]; then
        export SNS_TOPIC_ARN="$SNS_ARN"
    fi

    echo "✅ Secrets loaded successfully"
else
    echo "⚠️  Not running in AWS - using environment variables"
    echo "   (This is normal for local development)"
fi

# ----------------------------------------------------------------------------
# VALIDATE REQUIRED ENVIRONMENT VARIABLES
# ----------------------------------------------------------------------------

echo ""
echo "🔍 Validating configuration..."

# Check if critical variables are set
if [ -z "$S3_BUCKET_NAME" ]; then
    echo "⚠️  WARNING: S3_BUCKET_NAME not set"
fi

if [ -z "$SECRET_KEY" ]; then
    echo "⚠️  WARNING: SECRET_KEY not set - Flask will use insecure default"
fi

if [ -z "$DATABASE_URL" ]; then
    echo "ℹ️  DATABASE_URL not set - using default SQLite"
fi

# ----------------------------------------------------------------------------
# DISPLAY CONFIGURATION (WITHOUT EXPOSING SECRETS)
# ----------------------------------------------------------------------------

echo ""
echo "⚙️  Application Configuration:"
echo "   - Environment: ${FLASK_ENV:-not set}"
echo "   - S3 Bucket: ${S3_BUCKET_NAME:-not set}"
echo "   - Database: ${DATABASE_URL:-not set}"
echo "   - Secret Key: ${SECRET_KEY:+***configured***}"  # Only show if set
echo "   - SNS Topic: ${SNS_TOPIC_ARN:+***configured***}"
echo "   - AWS Region: $AWS_REGION"

# ----------------------------------------------------------------------------
# START APPLICATION
# ----------------------------------------------------------------------------

echo ""
echo "🎯 Starting Flask application..."
echo "==============================================="

# Start Flask with Gunicorn (production WSGI server)
# Better than Flask's built-in dev server for production

# Check if we should use Gunicorn (production) or Flask dev server (local)
if [ "$FLASK_ENV" = "production" ]; then
    echo "🚀 Starting with Gunicorn (production mode)"
    exec gunicorn \
        --bind 0.0.0.0:5000 \
        --workers 2 \
        --threads 2 \
        --timeout 60 \
        --access-logfile - \
        --error-logfile - \
        --log-level info \
        --chdir /app/backend \
        app:app
else
    echo "🛠️  Starting with Flask dev server (development mode)"
    exec python backend/app.py
fi

# Note: 'exec' replaces this script process with the app process
# This allows proper signal handling (CTRL+C, docker stop, etc.)
