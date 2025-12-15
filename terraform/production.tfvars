# Region & Domain
aws_region  = "eu-west-1"
environment = "prod"
domain_name = "nt-nick.link"
subdomain   = "codedetect"

# Your Contact
owner_email        = "nyeinthunaing322@gmail.com"
notification_email = "nyeinthunaing322@gmail.com"

# Security - SSH access from anywhere (dynamic IP)
allowed_ssh_ip = "0.0.0.0/0" # Allow from anywhere since IP changes dynamically

# Storage (must be globally unique!)
s3_bucket_name = "codedetect-nick-uploads-12345"

# Database password (RDS enabled - fetched from Parameter Store in production)
db_password = "ChangeMe123!" # Placeholder - actual password in Parameter Store

# Cost Optimization
instance_type     = "t3.micro"
use_rds           = true
enable_https      = true
enable_monitoring = true

# Docker Configuration
docker_image_repo = "nyeinthunaing/codedetect"
docker_tag        = "latest"