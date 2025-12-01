#!/bin/bash
# ============================================================================
# DEPLOY STAGING ENVIRONMENT - On-Demand Script
# ============================================================================
# This script deploys a temporary staging environment for testing
# Use before deploying to production to avoid crashes!
#
# Usage:
#   ./deploy-staging.sh          # Deploy staging
#   ./deploy-staging.sh destroy  # Destroy staging
#
# Cost: ~$0.50 per 3-hour testing session
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if we're in the right directory
if [ ! -d "terraform" ]; then
    print_error "terraform/ directory not found!"
    print_info "Please run this script from the project root directory"
    exit 1
fi

# Navigate to terraform directory
cd terraform

# ============================================================================
# DESTROY MODE
# ============================================================================
if [ "$1" == "destroy" ] || [ "$1" == "down" ] || [ "$1" == "stop" ]; then
    print_header "DESTROYING STAGING ENVIRONMENT"

    print_warning "This will destroy all staging resources to save costs"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        print_info "Cancelled."
        exit 0
    fi

    # Switch to staging workspace
    print_info "Switching to staging workspace..."
    terraform workspace select staging 2>/dev/null || {
        print_warning "Staging workspace doesn't exist. Nothing to destroy."
        exit 0
    }

    # Destroy staging
    print_info "Destroying staging infrastructure..."
    terraform destroy -var-file="staging.tfvars" -auto-approve

    # Switch back to default
    print_info "Switching back to default workspace..."
    terraform workspace select default

    print_success "Staging environment destroyed!"
    print_info "Cost saved: ~\$0.15/hour"

    exit 0
fi

# ============================================================================
# DEPLOY MODE
# ============================================================================
print_header "DEPLOYING STAGING ENVIRONMENT"

# Check current workspace
current_workspace=$(terraform workspace show)
print_info "Current workspace: $current_workspace"

# Create staging workspace if it doesn't exist
if ! terraform workspace list | grep -q "staging"; then
    print_info "Creating staging workspace..."
    terraform workspace new staging
else
    print_info "Switching to staging workspace..."
    terraform workspace select staging
fi

# Verify we're in staging workspace
current_workspace=$(terraform workspace show)
if [ "$current_workspace" != "staging" ]; then
    print_error "Failed to switch to staging workspace!"
    exit 1
fi

print_success "Now in staging workspace"

# Check if staging.tfvars exists
if [ ! -f "staging.tfvars" ]; then
    print_error "staging.tfvars not found!"
    print_info "Please create staging.tfvars file first"
    exit 1
fi

# Initialize Terraform (if needed)
print_info "Initializing Terraform..."
terraform init -upgrade > /dev/null 2>&1

# Show what will be created
print_header "TERRAFORM PLAN"
print_info "Reviewing what will be created..."
echo ""

terraform plan -var-file="staging.tfvars" -no-color | tail -n 20

echo ""
print_warning "This will create NEW resources (not modify production)"
print_info "Estimated cost: ~\$0.50 for 3-hour session"
echo ""

read -p "Deploy staging environment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Deployment cancelled."
    terraform workspace select default
    exit 0
fi

# Deploy staging
print_header "DEPLOYING STAGING"
print_info "This will take 5-10 minutes..."
echo ""

terraform apply -var-file="staging.tfvars" -auto-approve

# Get staging URL
print_header "STAGING DEPLOYED SUCCESSFULLY!"
echo ""

STAGING_URL=$(terraform output -raw load_balancer_url 2>/dev/null || echo "Not available yet")

print_success "Staging environment is ready!"
echo ""
echo -e "${GREEN}📍 Staging URL:${NC}"
echo -e "${BLUE}   $STAGING_URL${NC}"
echo ""
echo -e "${GREEN}📋 Quick Commands:${NC}"
echo -e "   Test health:  ${BLUE}curl $STAGING_URL/api/health${NC}"
echo -e "   Open browser: ${BLUE}$STAGING_URL${NC}"
echo ""
echo -e "${YELLOW}💡 Usage Tips:${NC}"
echo "   1. Test your changes on staging URL"
echo "   2. If it works ✓ → Deploy to production"
echo "   3. If it breaks ✗ → Fix and redeploy to staging"
echo "   4. When done testing, run: ${BLUE}./deploy-staging.sh destroy${NC}"
echo ""
print_warning "Don't forget to destroy staging when done to save costs!"
echo ""

# Switch back to default workspace
print_info "Switching back to default workspace..."
terraform workspace select default

print_success "Done! Staging is ready for testing."
echo ""
