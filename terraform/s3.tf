# ============================================================================
# S3 BUCKET - FILE STORAGE
# ============================================================================
# S3 bucket for storing uploaded Python files for analysis
# ============================================================================

# ----------------------------------------------------------------------------
# S3 BUCKET
# ----------------------------------------------------------------------------
resource "aws_s3_bucket" "uploads" {
  bucket = var.s3_bucket_name  # Must be globally unique

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-uploads"
    }
  )
}

# ----------------------------------------------------------------------------
# BUCKET VERSIONING
# ----------------------------------------------------------------------------
# Keep old versions of files (can recover if accidentally deleted)
resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = var.s3_enable_versioning ? "Enabled" : "Suspended"
  }
}

# ----------------------------------------------------------------------------
# BUCKET ENCRYPTION
# ----------------------------------------------------------------------------
# Encrypt all files at rest (security best practice)
resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # AWS-managed encryption keys
    }
  }
}

# ----------------------------------------------------------------------------
# BLOCK PUBLIC ACCESS
# ----------------------------------------------------------------------------
# Prevent accidental public exposure (security best practice)
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------------------------------------------------------------------
# LIFECYCLE RULES
# ----------------------------------------------------------------------------
# Automatically delete old files to save costs
resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  # Delete old versions after 30 days
  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}  # Empty filter applies to all objects

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Clean up incomplete multipart uploads after 7 days
  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    filter {}  # Empty filter applies to all objects

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Optional: Auto-delete uploaded files after 90 days
  # Uncomment if you want automatic cleanup
  # rule {
  #   id     = "expire-old-files"
  #   status = "Enabled"
  #
  #   expiration {
  #     days = 90
  #   }
  # }
}

# ============================================================================
# S3 EXPLANATION
# ============================================================================

# WHAT IS S3?
# - Simple Storage Service
# - Object storage (like Dropbox but for apps)
# - Store files, images, backups, logs, etc.
# - Highly durable (99.999999999% durability)
# - Pay only for what you use

# WHY USE S3?
# - Scalable: Store unlimited files
# - Reliable: Files won't get lost
# - Cheap: ~$0.023/GB/month
# - Secure: Encryption, access control
# - Fast: Globally distributed

# VERSIONING:
# - Keep history of all changes
# - Can restore deleted files
# - Costs extra (stores multiple versions)
# - Good for: Important files, compliance

# LIFECYCLE RULES:
# - Automatically manage old files
# - Delete old versions to save money
# - Clean up incomplete uploads
# - Can move to cheaper storage tiers

# ENCRYPTION:
# - AES256 encryption at rest
# - Protects data if disk is stolen
# - No performance impact
# - Free (AWS-managed keys)

# PUBLIC ACCESS BLOCK:
# - Prevents accidental public exposure
# - Critical for security
# - Even if policy allows, this blocks it
# - Best practice for all private buckets

# BUCKET NAMING:
# - Must be globally unique across ALL AWS
# - Can only contain lowercase letters, numbers, hyphens
# - Cannot start/end with hyphen
# - 3-63 characters long
# - Example: "codedetect-nick-uploads-12345"

# COSTS:
# - Storage: $0.023/GB/month (first 50 TB)
# - Requests: $0.0004 per 1,000 GET requests
# - Data transfer out: $0.09/GB (first 10 TB)
# - For student project: Usually < $1/month

# ============================================================================
