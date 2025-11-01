#!/bin/bash
# Helper script to display secret values for GitHub Secrets setup
# Run this script and copy the outputs to GitHub Secrets

echo "======================================================================="
echo "GitHub Secrets Setup Helper"
echo "======================================================================="
echo ""
echo "Copy these values to GitHub → Settings → Secrets and variables → Actions"
echo ""

# EC2_HOST
echo "======================================================================="
echo "Secret Name: EC2_HOST"
echo "======================================================================="
echo "108.128.137.219"
echo ""

# EC2_USER
echo "======================================================================="
echo "Secret Name: EC2_USER"
echo "======================================================================="
echo "ec2-user"
echo ""

# SSH_PRIVATE_KEY
echo "======================================================================="
echo "Secret Name: SSH_PRIVATE_KEY"
echo "======================================================================="
echo "IMPORTANT: Copy the ENTIRE key including BEGIN/END lines"
echo ""
if [ -f "../terraform/codedetect-key" ]; then
    cat ../terraform/codedetect-key
else
    echo "ERROR: SSH key not found at ../terraform/codedetect-key"
    echo "Please locate your codedetect-key file and copy its contents"
fi
echo ""

# AWS credentials (for Option 2)
echo "======================================================================="
echo "OPTIONAL - For ECR Deployment (Option 2)"
echo "======================================================================="
echo ""

echo "Secret Name: AWS_ACCESS_KEY_ID"
if command -v aws &> /dev/null; then
    AWS_KEY=$(aws configure get aws_access_key_id 2>/dev/null)
    if [ ! -z "$AWS_KEY" ]; then
        echo "$AWS_KEY"
    else
        echo "Run: aws configure get aws_access_key_id"
    fi
else
    echo "AWS CLI not found. Install it or get from ~/.aws/credentials"
fi
echo ""

echo "Secret Name: AWS_SECRET_ACCESS_KEY"
if command -v aws &> /dev/null; then
    AWS_SECRET=$(aws configure get aws_secret_access_key 2>/dev/null)
    if [ ! -z "$AWS_SECRET" ]; then
        echo "$AWS_SECRET"
    else
        echo "Run: aws configure get aws_secret_access_key"
    fi
else
    echo "AWS CLI not found. Install it or get from ~/.aws/credentials"
fi
echo ""

echo "Secret Name: AWS_ACCOUNT_ID"
if command -v aws &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [ ! -z "$ACCOUNT_ID" ]; then
        echo "$ACCOUNT_ID"
    else
        echo "Run: aws sts get-caller-identity --query Account --output text"
    fi
else
    echo "AWS CLI not found. Run: aws sts get-caller-identity"
fi
echo ""

echo "======================================================================="
echo "Next Steps:"
echo "======================================================================="
echo "1. Go to: https://github.com/Ntnick-22/codeDetect/settings/secrets/actions"
echo "2. Click 'New repository secret' for each value above"
echo "3. Copy-paste the values (be careful with the SSH key!)"
echo "4. Push a commit to test the workflow"
echo ""
echo "Done! 🚀"
echo "======================================================================="
