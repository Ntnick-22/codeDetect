#!/bin/bash

# ============================================================================
# BLUE/GREEN DEPLOYMENT SCRIPT
# ============================================================================
# This script helps you switch between blue and green environments
# Usage: ./blue-green-deploy.sh [blue|green|status]
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show current status
show_status() {
    print_info "Checking current deployment status..."

    # Get current active environment from Terraform
    CURRENT_ENV=$(terraform output -raw active_environment 2>/dev/null || echo "unknown")

    if [ "$CURRENT_ENV" == "unknown" ]; then
        print_error "Could not determine current environment. Run 'terraform apply' first."
        exit 1
    fi

    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Current Active Environment: $CURRENT_ENV"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get ALB DNS
    ALB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "unknown")
    print_info "Load Balancer: $ALB_DNS"

    # Get ASG names
    BLUE_ASG=$(terraform output -raw blue_asg_name 2>/dev/null || echo "unknown")
    GREEN_ASG=$(terraform output -raw green_asg_name 2>/dev/null || echo "unknown")

    print_info ""
    print_info "Blue ASG: $BLUE_ASG"
    print_info "Green ASG: $GREEN_ASG"

    # Check instance counts
    print_info ""
    print_info "Checking instance counts..."

    if command -v aws &> /dev/null; then
        BLUE_COUNT=$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$BLUE_ASG" \
            --query 'AutoScalingGroups[0].DesiredCapacity' \
            --output text 2>/dev/null || echo "0")

        GREEN_COUNT=$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$GREEN_ASG" \
            --query 'AutoScalingGroups[0].DesiredCapacity' \
            --output text 2>/dev/null || echo "0")

        if [ "$CURRENT_ENV" == "blue" ]; then
            print_success "🟦 BLUE: $BLUE_COUNT instances (ACTIVE - receiving traffic)"
            print_info "🟩 GREEN: $GREEN_COUNT instances (standby)"
        else
            print_info "🟦 BLUE: $BLUE_COUNT instances (standby)"
            print_success "🟩 GREEN: $GREEN_COUNT instances (ACTIVE - receiving traffic)"
        fi
    else
        print_warning "AWS CLI not found. Install it to see instance counts."
    fi

    print_info ""
    print_info "Access your application at: https://$ALB_DNS"
}

# Function to deploy to a specific environment
deploy() {
    TARGET_ENV=$1
    DOCKER_TAG=${2:-"v1.0"}  # Default to v1.0 if not specified
    CURRENT_ENV=$(terraform output -raw active_environment 2>/dev/null || echo "unknown")

    if [ "$TARGET_ENV" == "$CURRENT_ENV" ]; then
        print_warning "$TARGET_ENV is already the active environment!"
        print_info "Nothing to do."
        exit 0
    fi

    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_warning "BLUE/GREEN DEPLOYMENT"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Current Active: $CURRENT_ENV"
    print_info "Target Environment: $TARGET_ENV"
    print_info "Docker Tag: $DOCKER_TAG"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info ""

    # Confirm with user
    read -p "Do you want to switch traffic to $TARGET_ENV with version $DOCKER_TAG? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        print_info "Deployment cancelled."
        exit 0
    fi

    print_info ""
    print_info "Step 1/3: Running Terraform plan..."
    terraform plan -var="active_environment=$TARGET_ENV" -var="docker_tag=$DOCKER_TAG" -out=tfplan

    print_info ""
    print_warning "Review the plan above. This will:"
    print_info "  - Scale UP $TARGET_ENV Auto Scaling Group (0 → 2 instances)"
    print_info "  - Switch ALB listener to forward traffic to $TARGET_ENV"
    print_info "  - Scale DOWN $CURRENT_ENV Auto Scaling Group (2 → 0 instances)"
    print_info ""

    read -p "Apply these changes? (yes/no): " CONFIRM_APPLY
    if [ "$CONFIRM_APPLY" != "yes" ]; then
        print_info "Deployment cancelled."
        rm -f tfplan
        exit 0
    fi

    print_info ""
    print_info "Step 2/3: Applying Terraform changes..."
    terraform apply tfplan
    rm -f tfplan

    print_success "Terraform apply completed!"

    print_info ""
    print_info "Step 3/3: Waiting for $TARGET_ENV instances to be healthy..."
    print_info "This may take 5-10 minutes..."

    if command -v aws &> /dev/null; then
        TARGET_ASG=""
        if [ "$TARGET_ENV" == "blue" ]; then
            TARGET_ASG=$(terraform output -raw blue_asg_name)
        else
            TARGET_ASG=$(terraform output -raw green_asg_name)
        fi

        MAX_WAIT=600  # 10 minutes
        ELAPSED=0

        while [ $ELAPSED -lt $MAX_WAIT ]; do
            HEALTHY_COUNT=$(aws autoscaling describe-auto-scaling-groups \
                --auto-scaling-group-names "$TARGET_ASG" \
                --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`]|length(@)' \
                --output text 2>/dev/null || echo "0")

            DESIRED_COUNT=$(aws autoscaling describe-auto-scaling-groups \
                --auto-scaling-group-names "$TARGET_ASG" \
                --query 'AutoScalingGroups[0].DesiredCapacity' \
                --output text 2>/dev/null || echo "0")

            print_info "Healthy instances: $HEALTHY_COUNT / $DESIRED_COUNT"

            if [ "$HEALTHY_COUNT" -ge "$DESIRED_COUNT" ] && [ "$DESIRED_COUNT" -gt "0" ]; then
                print_success "All instances are healthy!"
                break
            fi

            sleep 30
            ELAPSED=$((ELAPSED + 30))
        done

        if [ $ELAPSED -ge $MAX_WAIT ]; then
            print_warning "Health check timeout. Please verify instances manually."
        fi
    else
        print_warning "AWS CLI not found. Please check instance health manually."
    fi

    print_info ""
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "DEPLOYMENT COMPLETE!"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Active environment is now: $TARGET_ENV"
    print_info ""
    print_info "Your application is now running on $TARGET_ENV environment!"
    print_info "Test your application and verify everything works."
    print_info ""
    print_warning "Old environment ($CURRENT_ENV) will scale down to 0 instances automatically."
    print_info ""
    ALB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null)
    print_info "Access your application: https://$ALB_DNS"
}

# Main script
main() {
    COMMAND=${1:-status}
    DOCKER_TAG=${2:-"v1.0"}

    case $COMMAND in
        blue)
            deploy "blue" "$DOCKER_TAG"
            ;;
        green)
            deploy "green" "$DOCKER_TAG"
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            echo "Blue/Green Deployment Script"
            echo ""
            echo "Usage: $0 [command] [docker_tag]"
            echo ""
            echo "Commands:"
            echo "  blue [tag]    - Switch traffic to blue environment with optional Docker tag"
            echo "  green [tag]   - Switch traffic to green environment with optional Docker tag"
            echo "  status        - Show current deployment status (default)"
            echo "  help          - Show this help message"
            echo ""
            echo "Docker Tag:"
            echo "  - Optional version tag (default: v1.0)"
            echo "  - Must match a tag in Docker Hub: nyeinthunaing/codedetect:<tag>"
            echo ""
            echo "Examples:"
            echo "  $0 status                # Show current status"
            echo "  $0 blue                  # Switch to blue with default tag (v1.0)"
            echo "  $0 blue v1.1             # Switch to blue with v1.1"
            echo "  $0 green v1.2            # Switch to green with v1.2"
            echo ""
            echo "Blue/Green Workflow:"
            echo "  1. Build new Docker image:  cd .. && ./build-and-push.sh v1.1"
            echo "  2. Deploy to standby env:   $0 green v1.1"
            echo "  3. Test the new version:    curl https://your-alb-dns/"
            echo "  4. Rollback if needed:      $0 blue v1.0"
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            print_info "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
