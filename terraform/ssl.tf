# ============================================================================
# SSL/TLS CERTIFICATE CONFIGURATION
# ============================================================================
# This file sets up HTTPS for your application using AWS Certificate Manager
# - Free SSL certificate from AWS
# - Automatic DNS validation via Route53
# - HTTPS on port 443
# ============================================================================

# ----------------------------------------------------------------------------
# REQUEST SSL CERTIFICATE
# ----------------------------------------------------------------------------
# Request a free SSL certificate from AWS Certificate Manager

resource "aws_acm_certificate" "main" {
  count             = var.enable_dns ? 1 : 0  # Only create if DNS enabled
  domain_name       = "${var.subdomain}.${var.domain_name}"  # codedetect.nt-nick.link
  validation_method = "DNS"                                   # Verify ownership via Route53

  # Optional: Add wildcard for subdomains (e.g., api.codedetect.nt-nick.link)
  # subject_alternative_names = [
  #   "*.${var.subdomain}.${var.domain_name}"
  # ]

  lifecycle {
    create_before_destroy = true  # When renewing, create new cert before destroying old
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-certificate"
    }
  )
}

# ----------------------------------------------------------------------------
# DNS VALIDATION RECORD
# ----------------------------------------------------------------------------
# AWS gives us a CNAME record to prove we own the domain
# We automatically add it to Route53

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_dns ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# ----------------------------------------------------------------------------
# WAIT FOR CERTIFICATE VALIDATION
# ----------------------------------------------------------------------------
# Terraform waits here until AWS validates the certificate (usually 5-10 min)

resource "aws_acm_certificate_validation" "main" {
  count                   = var.enable_dns ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "15m"  # Wait up to 15 minutes for validation
  }
}

# ----------------------------------------------------------------------------
# HTTPS LISTENER (Port 443)
# ----------------------------------------------------------------------------
# Add HTTPS listener to the Application Load Balancer

resource "aws_lb_listener" "https" {
  count             = var.enable_dns ? 1 : 0  # Only create if DNS enabled
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"

  # SSL policy - defines which encryption protocols to use
  # ELBSecurityPolicy-2016-08 is a good balance of security and compatibility
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  # Attach our SSL certificate
  certificate_arn   = aws_acm_certificate_validation.main[0].certificate_arn

  # Blue/Green Deployment: Forward traffic to active environment
  # This uses the active_environment variable to determine which target group receives traffic
  default_action {
    type             = "forward"
    target_group_arn = var.active_environment == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name               = "${local.name_prefix}-https-listener"
      ActiveEnvironment  = var.active_environment
    }
  )

  depends_on = [aws_acm_certificate_validation.main]
}

# ============================================================================
# SSL/TLS EXPLANATION
# ============================================================================

# WHAT IS SSL/TLS?
# - SSL (Secure Sockets Layer) - Old name
# - TLS (Transport Layer Security) - Current name, more secure
# - Encrypts data between browser and server
# - Prevents eavesdropping, tampering, and impersonation

# WHY DO WE NEED IT?
# - Security: Protects user data (passwords, uploads, etc.)
# - Trust: Browsers show padlock icon, users trust your site
# - SEO: Google ranks HTTPS sites higher
# - Required: Many features (like camera access) require HTTPS

# HOW IT WORKS:
# 1. User visits https://codedetect.nt-nick.link
# 2. ALB presents SSL certificate
# 3. Browser verifies certificate is valid and trusted
# 4. Browser and ALB negotiate encryption
# 5. All data is encrypted in transit

# CERTIFICATE VALIDATION:
# - AWS needs to verify you own the domain
# - DNS validation: AWS gives us a CNAME record to add to Route53
# - Terraform automatically adds it for us
# - AWS checks the record exists → Issues certificate
# - Takes 5-10 minutes usually

# SSL TERMINATION:
# - ALB handles encryption/decryption (called "SSL termination")
# - Traffic flow: User -(HTTPS)-> ALB -(HTTP)-> EC2
# - Benefits:
#   * Your app doesn't need to handle SSL
#   * Better performance (ALB has hardware acceleration)
#   * One certificate for all backend instances
#   * Easier to manage and renew

# SSL POLICY:
# - Defines which encryption protocols are allowed
# - ELBSecurityPolicy-2016-08:
#   * TLS 1.0, 1.1, 1.2 (good browser compatibility)
#   * Strong ciphers only
#   * Good balance of security and compatibility
# - For stricter security, use ELBSecurityPolicy-TLS-1-2-2017-01
#   (blocks TLS 1.0/1.1, but may break old browsers)

# CERTIFICATE RENEWAL:
# - ACM certificates auto-renew before expiration (every 13 months)
# - You don't need to do anything manually
# - AWS handles everything automatically

# COST:
# - ACM certificates: FREE
# - HTTPS requests: Same cost as HTTP
# - No additional charges for SSL/TLS

# ============================================================================
