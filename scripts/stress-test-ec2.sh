#!/bin/bash
# Stress test EC2 instance to trigger CloudWatch alarms
# This will spike CPU to >80% and trigger email alerts

echo "================================================"
echo "EC2 Stress Test - CloudWatch Alarm Demo"
echo "================================================"
echo ""
echo "This script will:"
echo "1. Stress CPU to 100% for 5 minutes"
echo "2. Trigger CloudWatch High CPU alarm (>80%)"
echo "3. Send email alert via SNS"
echo ""
echo "Expected timeline:"
echo "- 0:00 - Start CPU stress"
echo "- 5:00 - CPU stays high (evaluation period)"
echo "- 5:00 - CloudWatch alarm triggers"
echo "- 5:01 - Email notification sent"
echo ""
read -p "Press Enter to start stress test..."

# Check if stress tool is installed
if ! command -v stress &> /dev/null; then
    echo "Installing stress tool..."
    sudo yum install -y stress
fi

# Get current CPU before test
echo ""
echo "Current CPU usage:"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'

echo ""
echo "🔥 Starting CPU stress test..."
echo "   - Duration: 6 minutes (to ensure alarm triggers)"
echo "   - CPU cores: 2 (100% utilization)"
echo ""
echo "Monitor in real-time:"
echo "   - AWS Console: CloudWatch → Alarms"
echo "   - Dashboard: http://codedetect.nt-nick.link (Deployment section)"
echo "   - Email: Check inbox for SNS notification"
echo ""

# Run stress test
# --cpu 2 = stress both CPU cores
# --timeout 360s = run for 6 minutes
stress --cpu 2 --timeout 360s &

STRESS_PID=$!
echo "Stress test running (PID: $STRESS_PID)"
echo ""
echo "Monitoring CPU usage every 30 seconds..."

# Monitor CPU for 6 minutes
for i in {1..12}; do
    sleep 30
    CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo "[$i/12] CPU: ${CPU}% (Target: >80% for alarm)"

    if (( $(echo "$CPU > 80" | bc -l) )); then
        echo "       ✅ Above alarm threshold!"
    fi
done

echo ""
echo "✅ Stress test complete!"
echo ""
echo "Next steps:"
echo "1. Wait 1-2 minutes for CloudWatch to evaluate metrics"
echo "2. Check AWS Console: CloudWatch → Alarms"
echo "3. Check your email for SNS notification"
echo "4. Alarm should auto-resolve after CPU drops back to normal"
echo ""
echo "To verify alarm status:"
echo "aws cloudwatch describe-alarms --region eu-west-1 --alarm-names codedetect-prod-high-cpu"
