# ============================================================================
# ROUTE 53 - DNS CONFIGURATION
# ============================================================================
# Connects your domain (nt-nick.link) to your EC2 instance
# ============================================================================

# ----------------------------------------------------------------------------
# GET EXISTING HOSTED ZONE
# ----------------------------------------------------------------------------
# You already own nt-nick.link, so we just reference it
# Don't create a new one - just get the existing one

data "aws_route53_zone" "main" {
  name         = var.domain_name  # "nt-nick.link"
  private_zone = false            # Public hosted zone (accessible from internet)
}

# ----------------------------------------------------------------------------
# CREATE DNS RECORD
# ----------------------------------------------------------------------------
# Points your subdomain (codedetect.nt-nick.link) to your EC2's IP

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id  # Your hosted zone
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"  # A record = maps domain to IPv4 address
  ttl     = 300  # Time To Live = 5 minutes (how long DNS is cached)

  # Point to your EC2's Elastic IP
  records = [aws_eip.main.public_ip]

  # Wait for EIP to be created first
  depends_on = [aws_eip.main]
}

# ============================================================================
# ROUTE 53 EXPLANATION
# ============================================================================

# WHAT IS ROUTE 53?
# - AWS's DNS (Domain Name System) service
# - Translates domain names to IP addresses
# - Like a phone book for the internet
# - Example: nt-nick.link → 54.123.456.789

# DNS RECORD TYPES:
# - A Record: Maps domain to IPv4 address (what we use)
# - AAAA Record: Maps domain to IPv6 address
# - CNAME: Maps domain to another domain (alias)
# - MX: Mail exchange (for email)
# - TXT: Text records (for verification, SPF, etc.)

# HOSTED ZONE:
# - Container for DNS records for a domain
# - You already created this when you bought nt-nick.link
# - We just reference it, don't create new one
# - Costs $0.50/month per hosted zone

# TTL (Time To Live):
# - How long DNS servers cache the record
# - 300 seconds = 5 minutes
# - Lower TTL = changes propagate faster, more DNS queries (costs more)
# - Higher TTL = changes propagate slower, fewer DNS queries (costs less)
# - 300-3600 seconds is typical

# DNS PROPAGATION:
# - When you create/change DNS records, takes time to spread
# - Can take 5 minutes to 48 hours (usually < 1 hour)
# - Different DNS servers update at different times
# - Use low TTL (300) during setup for faster changes

# YOUR SETUP:
# - Domain: nt-nick.link (you own this)
# - Subdomain: codedetect (we're adding this)
# - Full URL: codedetect.nt-nick.link
# - Points to: Your EC2 Elastic IP

# ALTERNATIVE: ROOT DOMAIN
# If you want to use nt-nick.link (without subdomain):
# - Set subdomain = "" in variables
# - URL becomes: http://nt-nick.link

# HOW IT WORKS:
# 1. User types: codedetect.nt-nick.link
# 2. Browser asks DNS: "What IP is this?"
# 3. Route 53 responds: "54.123.456.789"
# 4. Browser connects to that IP
# 5. EC2 instance receives the request
# 6. Docker container serves your app

# PRICING:
# - Hosted Zone: $0.50/month (you already pay this)
# - DNS Queries: $0.40 per million queries (first 1B is $0.40)
# - For student project: ~$0.50/month total
# - Basically just the hosted zone cost

# ============================================================================

# ----------------------------------------------------------------------------
# OPTIONAL: WWW REDIRECT
# ----------------------------------------------------------------------------
# Uncomment to redirect www.codedetect.nt-nick.link → codedetect.nt-nick.link

# resource "aws_route53_record" "www" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "www.${var.subdomain}.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = ["${var.subdomain}.${var.domain_name}"]
# }

# ----------------------------------------------------------------------------
# OPTIONAL: HEALTH CHECK
# ----------------------------------------------------------------------------
# Monitor if your website is up and send alerts if it goes down

# resource "aws_route53_health_check" "app" {
#   fqdn              = "${var.subdomain}.${var.domain_name}"
#   port              = 80
#   type              = "HTTP"
#   resource_path     = "/api/health"
#   failure_threshold = 3
#   request_interval  = 30
#
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.name_prefix}-health-check"
#     }
#   )
# }

# ============================================================================