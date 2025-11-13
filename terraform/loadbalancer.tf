# ============================================================================
# CODEDETECT - APPLICATION LOAD BALANCER & HIGH AVAILABILITY
# ============================================================================
# This file sets up high availability architecture:
# - Application Load Balancer (ALB) for traffic distribution
# - Auto Scaling Group with 2+ instances
# - Multi-AZ deployment for redundancy
# - Automatic failover when instance fails
# ============================================================================

# ----------------------------------------------------------------------------
# SECURITY GROUP - Application Load Balancer
# ----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )
}

# Allow HTTP traffic from internet
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  tags = {
    Name = "${local.name_prefix}-alb-http-ingress"
  }
}

# Allow HTTPS traffic from internet
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "${local.name_prefix}-alb-https-ingress"
  }
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${local.name_prefix}-alb-egress"
  }
}

# ----------------------------------------------------------------------------
# UPDATE EC2 SECURITY GROUP - Allow traffic from ALB
# ----------------------------------------------------------------------------

# Allow traffic from ALB to EC2 on port 80 (Nginx reverse proxy)
resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow traffic from ALB to Nginx"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"

  tags = {
    Name = "${local.name_prefix}-ec2-from-alb"
  }
}

# ----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# ----------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false # Set true for production
  enable_http2               = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

# ----------------------------------------------------------------------------
# TARGET GROUP
# ----------------------------------------------------------------------------

resource "aws_lb_target_group" "app" {
  name     = "${local.name_prefix}-tg-v2"  # Changed name to force new resource
  port     = 80  # Changed from 5000 to 80 (Nginx reverse proxy)
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check configuration
  # ALB checks Nginx on port 80, which forwards to Flask app
  health_check {
    enabled             = true
    healthy_threshold   = 2   # 2 successful checks = healthy
    unhealthy_threshold = 3   # 3 failed checks = unhealthy
    timeout             = 5   # 5 seconds to respond
    interval            = 30  # Check every 30 seconds
    path                = "/api/health"  # Nginx forwards to codedetect:5000/api/health
    protocol            = "HTTP"
    matcher             = "200" # Expect HTTP 200 response
  }

  # Deregistration delay - wait before removing instance
  deregistration_delay = 30

  # Lifecycle: create new target group before destroying old one
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-target-group-v2"
    }
  )
}

# ----------------------------------------------------------------------------
# LISTENER - HTTP (Port 80)
# ----------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Redirect all HTTP traffic to HTTPS
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"  # Permanent redirect
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-http-listener"
    }
  )
}

# ----------------------------------------------------------------------------
# LAUNCH TEMPLATE
# ----------------------------------------------------------------------------

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  key_name = aws_key_pair.main.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(local.user_data)

  monitoring {
    enabled = var.enable_monitoring
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-asg-instance"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-asg-volume"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-launch-template"
    }
  )
}

# ----------------------------------------------------------------------------
# AUTO SCALING GROUP
# ----------------------------------------------------------------------------

resource "aws_autoscaling_group" "app" {
  name = "${local.name_prefix}-asg"

  # Capacity configuration
  min_size         = 2 # Minimum 2 instances (for HA)
  max_size         = 4 # Maximum 4 instances (can scale up if needed)
  desired_capacity = 2 # Start with 2 instances

  # Health check configuration
  health_check_type         = "ELB" # Use load balancer health checks
  health_check_grace_period = 300   # Wait 5 minutes before checking health

  # Network configuration
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  # Launch template
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Target group association
  target_group_arns = [aws_lb_target_group.app.arn]

  # Instance refresh on update
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 # Keep at least 50% healthy during refresh
    }
  }

  # Tags propagated to instances
  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Application"
    value               = local.app_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "AutoScaling"
    propagate_at_launch = true
  }
}

# ----------------------------------------------------------------------------
# AUTO SCALING POLICIES (Optional - for future scaling)
# ----------------------------------------------------------------------------

# Scale up when CPU > 70%
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${local.name_prefix}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# Scale down when CPU < 30%
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${local.name_prefix}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# CloudWatch alarm to trigger scale up
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_description = "Scale up when CPU exceeds 70%"
  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cpu-high-alarm"
    }
  )
}

# CloudWatch alarm to trigger scale down
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.name_prefix}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_description = "Scale down when CPU below 30%"
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cpu-low-alarm"
    }
  )
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "Full URL of the load balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}
