# ============================================================================
# EFS (ELASTIC FILE SYSTEM) - DEPRECATED
# ============================================================================
# This file is NO LONGER USED
#
# HISTORY:
# - Phase 1: Used EFS to share SQLite database between EC2 instances
# - Phase 2: Migrated to RDS PostgreSQL (current)
#
# WHY DEPRECATED:
# - Now using RDS PostgreSQL instead of SQLite
# - RDS is managed (automatic backups, updates, Multi-AZ)
# - Better performance for database workloads
# - Simpler architecture (no NFS mounting needed)
# - Cost: RDS ~$15/month vs EFS $0.30/month, but worth it for reliability
#
# FILES TO UPDATE:
# - monitoring.tf: Remove EFS metrics from dashboard
# - ec2.tf: Already cleaned (EFS mounting code removed)
#
# THIS FILE CAN BE SAFELY DELETED AFTER:
# 1. Running 'terraform destroy' to remove EFS resources from AWS
# 2. Removing EFS references in monitoring.tf
# 3. Verifying no other files reference aws_efs_file_system
#
# ============================================================================

# ALL RESOURCES COMMENTED OUT - NO LONGER USED

# resource "aws_efs_file_system" "main" {
#   encrypted        = true
#   performance_mode = "generalPurpose"
#   throughput_mode  = "bursting"
#
#   lifecycle_policy {
#     transition_to_ia = "AFTER_30_DAYS"
#   }
#
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.name_prefix}-efs-DEPRECATED"
#     }
#   )
# }

# resource "aws_efs_backup_policy" "main" {
#   file_system_id = aws_efs_file_system.main.id
#   backup_policy {
#     status = "DISABLED"
#   }
# }

# resource "aws_security_group" "efs" {
#   name        = "${local.name_prefix}-efs-sg"
#   description = "DEPRECATED - EFS security group"
#   vpc_id      = aws_vpc.main.id
#   tags        = local.common_tags
# }

# resource "aws_vpc_security_group_ingress_rule" "efs_from_ec2" {
#   security_group_id            = aws_security_group.efs.id
#   referenced_security_group_id = aws_security_group.ec2.id
#   from_port                    = 2049
#   to_port                      = 2049
#   ip_protocol                  = "tcp"
# }

# resource "aws_vpc_security_group_egress_rule" "efs_all" {
#   security_group_id = aws_security_group.efs.id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "-1"
# }

# resource "aws_efs_mount_target" "az1" {
#   file_system_id  = aws_efs_file_system.main.id
#   subnet_id       = aws_subnet.public_1.id
#   security_groups = [aws_security_group.efs.id]
# }

# resource "aws_efs_mount_target" "az2" {
#   file_system_id  = aws_efs_file_system.main.id
#   subnet_id       = aws_subnet.public_2.id
#   security_groups = [aws_security_group.efs.id]
# }

# resource "aws_efs_access_point" "database" {
#   file_system_id = aws_efs_file_system.main.id
#   root_directory {
#     path = "/database"
#     creation_info {
#       owner_gid   = 1000
#       owner_uid   = 1000
#       permissions = "755"
#     }
#   }
#   posix_user {
#     gid = 1000
#     uid = 1000
#   }
#   tags = local.common_tags
# }

# ============================================================================
# MIGRATION NOTES
# ============================================================================
#
# If you still have EFS running in AWS:
# 1. Backup any important data first
# 2. Run: terraform destroy -target=aws_efs_file_system.main
# 3. Verify in AWS Console that EFS is deleted
# 4. Remove this file entirely
#
# ============================================================================
