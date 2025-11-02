#!/bin/bash
# ============================================================================
# UPDATE GITHUB SECRETS AFTER TERRAFORM APPLY
# ============================================================================
# This script updates GitHub secrets with current EC2 values
# Run this after: terraform apply
# ============================================================================

set -e

echo "=== Updating GitHub Secrets with Current EC2 Values ==="
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo ""
    echo "Install it:"
    echo "  Windows: winget install GitHub.cli"
    echo "  Mac: brew install gh"
    echo "  Linux: sudo apt install gh"
    echo ""
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not logged in to GitHub CLI"
    echo ""
    echo "Run: gh auth login"
    echo ""
    exit 1
fi

echo "✅ GitHub CLI is ready"
echo ""

# Get values from Terraform
echo "📥 Getting values from Terraform..."
EC2_HOST=$(terraform output -raw ec2_public_ip)
EC2_USER="ec2-user"
SSH_KEY_FILE="codedetect-key"

echo "  EC2_HOST: $EC2_HOST"
echo "  EC2_USER: $EC2_USER"
echo "  SSH_KEY: $SSH_KEY_FILE"
echo ""

# Check if SSH key exists
if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "❌ SSH key file not found: $SSH_KEY_FILE"
    exit 1
fi

# Read SSH private key
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_FILE")

# Update GitHub secrets
echo "🔐 Updating GitHub secrets..."
echo ""

echo "  Updating EC2_HOST..."
echo "$EC2_HOST" | gh secret set EC2_HOST

echo "  Updating EC2_USER..."
echo "$EC2_USER" | gh secret set EC2_USER

echo "  Updating SSH_PRIVATE_KEY..."
echo "$SSH_PRIVATE_KEY" | gh secret set SSH_PRIVATE_KEY

echo ""
echo "✅ All secrets updated successfully!"
echo ""
echo "GitHub Secrets are now:"
echo "  EC2_HOST = $EC2_HOST"
echo "  EC2_USER = $EC2_USER"
echo "  SSH_PRIVATE_KEY = (hidden)"
echo ""
echo "🚀 Your CI/CD should work now!"
