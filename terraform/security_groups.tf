# ============================================================================
# SECURITY GROUPS - FIREWALL RULES
# ============================================================================
# Controls what traffic can reach your EC2 instance
# Think of it as a firewall for your server
# ============================================================================

# ----------------------------------------------------------------------------
# EC2 SECURITY GROUP
# ----------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for CodeDetect EC2 instance"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2-sg"
    }
  )
}

# ----------------------------------------------------------------------------
# INGRESS RULES (INCOMING TRAFFIC)
# ----------------------------------------------------------------------------

# SSH Access (Port 22) - For remote server access
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "SSH access for server management"

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_ssh_ip # Restrict to your IP for security

  tags = {
    Name = "SSH Access"
  }
}

# HTTP Access (Port 80) - For web traffic
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTP access for web application"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0" # Allow from anywhere

  tags = {
    Name = "HTTP Access"
  }
}

# HTTPS Access (Port 443) - For secure web traffic
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTPS access for secure web application"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0" # Allow from anywhere

  tags = {
    Name = "HTTPS Access"
  }
}

# ============================================================================
# PORTS 3000 AND 5000 REMOVED
# ============================================================================
# With Nginx reverse proxy, we no longer need to expose ports 3000 and 5000
# All traffic goes through port 80 (HTTP) and 443 (HTTPS)
#
# Architecture:
#   Internet → ALB (80/443) → EC2 (80) → Nginx → Services
#
# OLD (Direct Access):
#   - Port 5000: Flask app (exposed)
#   - Port 3000: Grafana (exposed)
#   ❌ Security risk: Services directly accessible
#
# NEW (Reverse Proxy):
#   - Port 80: Nginx (all traffic)
#   - Nginx routes to internal services
#   ✅ More secure: Services not exposed to internet
# ============================================================================

# Optional: Webhook Port (8000) - If using webhook deployment
# Uncomment if you switch back to webhook-based deployment
# resource "aws_vpc_security_group_ingress_rule" "webhook" {
#   security_group_id = aws_security_group.ec2.id
#   description       = "Webhook port for GitHub Actions deployment"
#
#   from_port   = 8000
#   to_port     = 8000
#   ip_protocol = "tcp"
#   cidr_ipv4   = "0.0.0.0/0"  # GitHub Actions IPs
#
#   tags = {
#     Name = "Webhook Port"
#   }
# }

# ----------------------------------------------------------------------------
# EGRESS RULES (OUTGOING TRAFFIC)
# ----------------------------------------------------------------------------

# Allow all outbound traffic (EC2 needs to download packages, etc.)
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1" # -1 means all protocols
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "Allow All Outbound"
  }
}

# ============================================================================
# SECURITY GROUP EXPLANATION
# ============================================================================

# WHAT IS A SECURITY GROUP?
# - Virtual firewall for your EC2 instance
# - Controls incoming (ingress) and outgoing (egress) traffic
# - Stateful: if you allow incoming traffic, responses are auto-allowed
# - Acts at instance level (not subnet level like NACLs)

# HOW IT WORKS:
# 1. By default, all inbound traffic is BLOCKED
# 2. By default, all outbound traffic is ALLOWED
# 3. You explicitly allow what you need
# 4. Rules are evaluated together (not in order)

# INGRESS vs EGRESS:
# - INGRESS: Traffic coming TO your server (downloads, requests)
# - EGRESS: Traffic going FROM your server (API calls, updates)

# PORT NUMBERS:
# - Port 22:    SSH (Secure Shell) - Remote access
# - Port 80:    HTTP - Web traffic (not encrypted)
# - Port 443:   HTTPS - Secure web traffic (encrypted)
# - Port 5000:  Flask application (custom)
# - Port 8000:  Webhook server (optional)

# CIDR NOTATION:
# - 0.0.0.0/0:        Allow from anywhere (the internet)
# - YOUR_IP/32:       Allow only from YOUR specific IP
# - 10.0.0.0/16:      Allow from entire VPC
# - 192.168.1.0/24:   Allow from specific subnet

# SECURITY BEST PRACTICES:
# ✅ Only allow necessary ports
# ✅ Restrict SSH to your IP (not 0.0.0.0/0)
# ✅ Use HTTPS (443) instead of HTTP (80) when possible
# ✅ Review rules regularly
# ✅ Delete unused rules
# ❌ Don't allow 0.0.0.0/0 for SSH in production
# ❌ Don't open all ports
# ❌ Don't use default security groups for production

# EXAMPLE USE CASES:
#
# Development:
# - Allow SSH from your home IP only
# - Allow HTTP/HTTPS from anywhere
# - Allow application port for testing
#
# Production:
# - SSH through bastion host only
# - HTTPS only (redirect HTTP to HTTPS)
# - Restrict admin ports
# - Use AWS Systems Manager instead of SSH
#
# Database Server:
# - No SSH (use Systems Manager)
# - Only database port (3306, 5432)
# - Only from application servers (not 0.0.0.0/0)

# COSTS:
# - Security Groups are FREE
# - No charge for rules or changes
# - No limit on number of rules (within AWS limits)

# TERRAFORM CHANGES:
# - If you change a rule, Terraform will update it
# - If you delete a rule from code, Terraform will remove it
# - Changes are immediate (no EC2 restart needed)

# ============================================================================
