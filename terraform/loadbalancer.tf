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
# TARGET GROUPS - BLUE/GREEN DEPLOYMENT
# ----------------------------------------------------------------------------

# BLUE Target Group (Primary)
resource "aws_lb_target_group" "blue" {
  name     = "${local.name_prefix}-blue-tg"
  port     = 80  # Nginx reverse proxy
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check configuration
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

  # Sticky sessions for session persistence
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 24 hours
    enabled         = true
  }

  # Lifecycle: create new target group before destroying old one
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-blue-target-group"
      Environment = "blue"
    }
  )
}

# GREEN Target Group (Secondary/Deployment)
resource "aws_lb_target_group" "green" {
  name     = "${local.name_prefix}-green-tg"
  port     = 80  # Nginx reverse proxy
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check configuration (identical to blue)
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  # Deregistration delay
  deregistration_delay = 30

  # Sticky sessions
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 24 hours
    enabled         = true
  }

  # Lifecycle
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-green-target-group"
      Environment = "green"
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

  key_name = data.aws_key_pair.main.key_name

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
# AUTO SCALING GROUPS - BLUE/GREEN DEPLOYMENT
# ----------------------------------------------------------------------------

# BLUE Auto Scaling Group
resource "aws_autoscaling_group" "blue" {
  name = "${local.name_prefix}-blue-asg"

  # Capacity configuration - controlled by active_environment variable
  # If blue is active: 2-4 instances
  # If green is active: 0 instances (scaled down)
  min_size         = var.active_environment == "blue" ? 2 : 0
  max_size         = var.active_environment == "blue" ? 4 : 0
  desired_capacity = var.active_environment == "blue" ? 2 : 0

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

  # Target group association - BLUE target group
  target_group_arns = [aws_lb_target_group.blue.arn]

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
    value               = "${local.name_prefix}-blue-instance"
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
    key                 = "DeploymentColor"
    value               = "blue"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "AutoScaling"
    propagate_at_launch = true
  }
}

# GREEN Auto Scaling Group
resource "aws_autoscaling_group" "green" {
  name = "${local.name_prefix}-green-asg"

  # Capacity configuration - controlled by active_environment variable
  # If green is active: 2-4 instances
  # If blue is active: 0 instances (scaled down)
  min_size         = var.active_environment == "green" ? 2 : 0
  max_size         = var.active_environment == "green" ? 4 : 0
  desired_capacity = var.active_environment == "green" ? 2 : 0

  # Health check configuration
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Network configuration
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  # Launch template
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Target group association - GREEN target group
  target_group_arns = [aws_lb_target_group.green.arn]

  # Instance refresh on update
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Tags propagated to instances
  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-green-instance"
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
    key                 = "DeploymentColor"
    value               = "green"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "AutoScaling"
    propagate_at_launch = true
  }
}

# ----------------------------------------------------------------------------
# AUTO SCALING POLICIES - BLUE ENVIRONMENT
# ----------------------------------------------------------------------------

# Blue: Scale up when CPU > 70%
resource "aws_autoscaling_policy" "blue_scale_up" {
  name                   = "${local.name_prefix}-blue-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.blue.name
}

# Blue: Scale down when CPU < 30%
resource "aws_autoscaling_policy" "blue_scale_down" {
  name                   = "${local.name_prefix}-blue-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.blue.name
}

# Blue: CloudWatch alarm to trigger scale up
resource "aws_cloudwatch_metric_alarm" "blue_cpu_high" {
  alarm_name          = "${local.name_prefix}-blue-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.blue.name
  }

  alarm_description = "Blue: Scale up when CPU exceeds 70%"
  alarm_actions     = [aws_autoscaling_policy.blue_scale_up.arn]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-blue-cpu-high-alarm"
      Environment = "blue"
    }
  )
}

# Blue: CloudWatch alarm to trigger scale down
resource "aws_cloudwatch_metric_alarm" "blue_cpu_low" {
  alarm_name          = "${local.name_prefix}-blue-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.blue.name
  }

  alarm_description = "Blue: Scale down when CPU below 30%"
  alarm_actions     = [aws_autoscaling_policy.blue_scale_down.arn]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-blue-cpu-low-alarm"
      Environment = "blue"
    }
  )
}

# ----------------------------------------------------------------------------
# AUTO SCALING POLICIES - GREEN ENVIRONMENT
# ----------------------------------------------------------------------------

# Green: Scale up when CPU > 70%
resource "aws_autoscaling_policy" "green_scale_up" {
  name                   = "${local.name_prefix}-green-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.green.name
}

# Green: Scale down when CPU < 30%
resource "aws_autoscaling_policy" "green_scale_down" {
  name                   = "${local.name_prefix}-green-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.green.name
}

# Green: CloudWatch alarm to trigger scale up
resource "aws_cloudwatch_metric_alarm" "green_cpu_high" {
  alarm_name          = "${local.name_prefix}-green-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.green.name
  }

  alarm_description = "Green: Scale up when CPU exceeds 70%"
  alarm_actions     = [aws_autoscaling_policy.green_scale_up.arn]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-green-cpu-high-alarm"
      Environment = "green"
    }
  )
}

# Green: CloudWatch alarm to trigger scale down
resource "aws_cloudwatch_metric_alarm" "green_cpu_low" {
  alarm_name          = "${local.name_prefix}-green-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.green.name
  }

  alarm_description = "Green: Scale down when CPU below 30%"
  alarm_actions     = [aws_autoscaling_policy.green_scale_down.arn]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-green-cpu-low-alarm"
      Environment = "green"
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

output "active_environment" {
  description = "Currently active environment (blue or green)"
  value       = var.active_environment
}

output "blue_target_group_arn" {
  description = "ARN of the blue target group"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "ARN of the green target group"
  value       = aws_lb_target_group.green.arn
}

output "blue_asg_name" {
  description = "Name of the blue Auto Scaling Group"
  value       = aws_autoscaling_group.blue.name
}

output "green_asg_name" {
  description = "Name of the green Auto Scaling Group"
  value       = aws_autoscaling_group.green.name
}
