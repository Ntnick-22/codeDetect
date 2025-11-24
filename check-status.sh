#!/bin/bash

# ============================================================================
# CHECK DEPLOYMENT STATUS SCRIPT
# ============================================================================
# This script is READ-ONLY - it never modifies infrastructure
# Use this to check current deployment status without risk
# ============================================================================

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 CodeDetect Deployment Status Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

echo "📊 Auto Scaling Groups Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get Blue environment status
blue_desired=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-blue-asg \
  --query 'AutoScalingGroups[0].DesiredCapacity' \
  --output text 2>/dev/null || echo "0")

blue_healthy=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-blue-asg \
  --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`]|length(@)' \
  --output text 2>/dev/null || echo "0")

# Get Green environment status
green_desired=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-green-asg \
  --query 'AutoScalingGroups[0].DesiredCapacity' \
  --output text 2>/dev/null || echo "0")

green_healthy=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names codedetect-prod-green-asg \
  --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`]|length(@)' \
  --output text 2>/dev/null || echo "0")

# Determine active environment
if [ "$blue_desired" -gt 0 ]; then
    active_env="BLUE"
    active_healthy="$blue_healthy"
    active_desired="$blue_desired"
    inactive_env="Green"
    inactive_healthy="$green_healthy"
    inactive_desired="$green_desired"
else
    active_env="GREEN"
    active_healthy="$green_healthy"
    active_desired="$green_desired"
    inactive_env="Blue"
    inactive_healthy="$blue_healthy"
    inactive_desired="$blue_desired"
fi

# Display Blue status
if [ "$blue_desired" -gt 0 ]; then
    echo "🔵 BLUE Environment:  ACTIVE ✅"
else
    echo "🔵 BLUE Environment:  Inactive (scaled to 0)"
fi
echo "   Desired: $blue_desired | Healthy: $blue_healthy"
echo ""

# Display Green status
if [ "$green_desired" -gt 0 ]; then
    echo "🟢 GREEN Environment: ACTIVE ✅"
else
    echo "🟢 GREEN Environment: Inactive (scaled to 0)"
fi
echo "   Desired: $green_desired | Healthy: $green_healthy"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Current Active Environment: $active_env"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get Load Balancer status
echo "🌐 Load Balancer Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

alb_dns=$(aws elbv2 describe-load-balancers \
  --names codedetect-prod-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text 2>/dev/null || echo "unknown")

echo "ALB DNS: $alb_dns"
echo "Domain:  codedetect.nt-nick.link"
echo ""

# Check target group health
echo "🎯 Target Group Health:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get target group ARNs
blue_tg_arn=$(aws elbv2 describe-target-groups \
  --names codedetect-prod-blue-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null)

green_tg_arn=$(aws elbv2 describe-target-groups \
  --names codedetect-prod-green-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null)

# Check Blue target health
blue_tg_health=$(aws elbv2 describe-target-health \
  --target-group-arn "$blue_tg_arn" \
  --query 'TargetHealthDescriptions[*].TargetHealth.State' \
  --output text 2>/dev/null || echo "unknown")

# Check Green target health
green_tg_health=$(aws elbv2 describe-target-health \
  --target-group-arn "$green_tg_arn" \
  --query 'TargetHealthDescriptions[*].TargetHealth.State' \
  --output text 2>/dev/null || echo "unknown")

echo "Blue TG:  $blue_tg_health"
echo "Green TG: $green_tg_health"
echo ""

# Application health check
echo "🏥 Application Health Check:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try health check via domain
domain_health=$(curl -s -o /dev/null -w "%{http_code}" https://codedetect.nt-nick.link/api/health 2>/dev/null || echo "000")

if [ "$domain_health" = "200" ]; then
    echo "✅ Domain Health:  OK (HTTP $domain_health)"
else
    echo "⚠️  Domain Health:  Failed (HTTP $domain_health)"
fi

# Try health check via ALB
alb_health=$(curl -s -o /dev/null -w "%{http_code}" http://$alb_dns/api/health 2>/dev/null || echo "000")

if [ "$alb_health" = "200" ]; then
    echo "✅ ALB Health:     OK (HTTP $alb_health)"
else
    echo "⚠️  ALB Health:     Failed (HTTP $alb_health)"
fi

echo ""

# Get application info if available
if [ "$alb_health" = "200" ]; then
    echo "📱 Application Info:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    app_info=$(curl -s http://$alb_dns/api/info 2>/dev/null || echo "{}")
    echo "$app_info" | head -10
    echo ""
fi

# Get Terraform state summary (read-only)
echo "🔧 Terraform State (from S3 backend):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "terraform" ]; then
    cd terraform

    # Initialize if needed (read-only)
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform (one-time setup)..."
        terraform init -backend=true > /dev/null 2>&1
    fi

    # Get active environment from state
    state_active=$(terraform output -raw active_environment 2>/dev/null || echo "unknown")
    state_docker_tag=$(terraform output -raw docker_tag 2>/dev/null || echo "unknown")

    echo "Active Environment (Terraform state): $state_active"
    echo "Docker Tag (Terraform state):         $state_docker_tag"
    echo ""

    cd ..
else
    echo "⚠️  Terraform directory not found"
    echo ""
fi

# Recent GitHub Actions runs
echo "🚀 Recent GitHub Actions Deployments:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "View at: https://github.com/Ntnick-22/codeDetect/actions"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Active Environment:     $active_env"
echo "Healthy Instances:      $active_healthy / $active_desired"
echo "Application Status:     $([ "$alb_health" = "200" ] && echo "✅ Running" || echo "❌ Down")"
echo "Domain:                 https://codedetect.nt-nick.link"
echo "ALB URL:                http://$alb_dns"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Tip: This script is read-only and safe to run anytime!"
echo "   For deployment, use: git push origin main"
echo ""
