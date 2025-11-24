#!/bin/bash

# ============================================================================
# CHECK INSTANCE LOGS SCRIPT
# ============================================================================
# This script helps you view logs from EC2 instances
# READ-ONLY - Safe to run anytime
# ============================================================================

set -e

# Check arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <environment>"
    echo ""
    echo "Examples:"
    echo "  $0 blue    # Check Blue environment logs"
    echo "  $0 green   # Check Green environment logs"
    exit 1
fi

ENVIRONMENT=$1

if [ "$ENVIRONMENT" != "blue" ] && [ "$ENVIRONMENT" != "green" ]; then
    echo "❌ Error: Environment must be 'blue' or 'green'"
    exit 1
fi

ASG_NAME="codedetect-prod-${ENVIRONMENT}-asg"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Checking Logs for $(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]') Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get instance IDs from ASG
echo "🔍 Finding instances in $ASG_NAME..."
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

if [ -z "$INSTANCE_IDS" ] || [ "$INSTANCE_IDS" = "None" ]; then
    echo "⚠️  No instances found in $ENVIRONMENT environment"
    echo "   The environment is likely scaled to 0 (inactive)"
    exit 0
fi

echo "Found instances: $INSTANCE_IDS"
echo ""

# For each instance
for INSTANCE_ID in $INSTANCE_IDS; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Instance: $INSTANCE_ID"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get instance details
    INSTANCE_INFO=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].[PublicIpAddress,State.Name,LaunchTime]' \
      --output text)

    PUBLIC_IP=$(echo "$INSTANCE_INFO" | awk '{print $1}')
    STATE=$(echo "$INSTANCE_INFO" | awk '{print $2}')
    LAUNCH_TIME=$(echo "$INSTANCE_INFO" | awk '{print $3}')

    echo "Public IP:   $PUBLIC_IP"
    echo "State:       $STATE"
    echo "Launch Time: $LAUNCH_TIME"
    echo ""

    if [ "$STATE" != "running" ]; then
        echo "⚠️  Instance is not running (state: $STATE)"
        echo ""
        continue
    fi

    echo "📝 Deployment Log (user data script execution):"
    echo "───────────────────────────────────────────────────────────────"

    # Get deployment log using SSM
    LOG_CONTENT=$(aws ssm send-command \
      --instance-ids "$INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["tail -50 /var/log/codedetect-deploy.log 2>/dev/null || echo \"Log file not found\""]' \
      --output text \
      --query 'Command.CommandId' 2>/dev/null)

    if [ -n "$LOG_CONTENT" ]; then
        sleep 2
        aws ssm get-command-invocation \
          --command-id "$LOG_CONTENT" \
          --instance-id "$INSTANCE_ID" \
          --query 'StandardOutputContent' \
          --output text 2>/dev/null || echo "Could not retrieve log via SSM"
    else
        echo "⚠️  SSM not available. Use SSH to check logs:"
        echo "   ssh -i codedetect-key ec2-user@$PUBLIC_IP"
        echo "   tail -f /var/log/codedetect-deploy.log"
    fi

    echo ""
    echo "🐳 Docker Containers:"
    echo "───────────────────────────────────────────────────────────────"

    # Check Docker containers
    DOCKER_PS=$(aws ssm send-command \
      --instance-ids "$INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\" 2>/dev/null || echo \"Docker not accessible\""]' \
      --output text \
      --query 'Command.CommandId' 2>/dev/null)

    if [ -n "$DOCKER_PS" ]; then
        sleep 2
        aws ssm get-command-invocation \
          --command-id "$DOCKER_PS" \
          --instance-id "$INSTANCE_ID" \
          --query 'StandardOutputContent' \
          --output text 2>/dev/null || echo "Could not retrieve Docker status via SSM"
    else
        echo "⚠️  SSM not available. Use SSH to check containers:"
        echo "   ssh -i codedetect-key ec2-user@$PUBLIC_IP"
        echo "   docker ps"
    fi

    echo ""
    echo "📊 Recent Docker Logs:"
    echo "───────────────────────────────────────────────────────────────"

    # Get recent Docker logs
    DOCKER_LOGS=$(aws ssm send-command \
      --instance-ids "$INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["cd /home/ec2-user/app && docker-compose logs --tail=20 2>/dev/null || echo \"Logs not available\""]' \
      --output text \
      --query 'Command.CommandId' 2>/dev/null)

    if [ -n "$DOCKER_LOGS" ]; then
        sleep 2
        aws ssm get-command-invocation \
          --command-id "$DOCKER_LOGS" \
          --instance-id "$INSTANCE_ID" \
          --query 'StandardOutputContent' \
          --output text 2>/dev/null || echo "Could not retrieve Docker logs via SSM"
    else
        echo "⚠️  SSM not available. Use SSH to check logs:"
        echo "   ssh -i codedetect-key ec2-user@$PUBLIC_IP"
        echo "   cd /home/ec2-user/app"
        echo "   docker-compose logs -f"
    fi

    echo ""
    echo "🔗 SSH Connection:"
    echo "───────────────────────────────────────────────────────────────"
    echo "To manually check this instance:"
    echo "  ssh -i codedetect-key ec2-user@$PUBLIC_IP"
    echo ""
    echo "Useful commands on the instance:"
    echo "  docker ps                      # List containers"
    echo "  docker-compose logs -f         # Follow logs"
    echo "  tail -f /var/log/codedetect-deploy.log  # Deployment log"
    echo "  docker images                  # List images"
    echo "  df -h                          # Check disk space"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Log check complete for $ENVIRONMENT environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Tips:"
echo "   - If SSM is not available, use SSH directly"
echo "   - For real-time logs: ssh to instance and run 'docker-compose logs -f'"
echo "   - Deployment logs: /var/log/codedetect-deploy.log"
echo ""
