#!/bin/bash
# ============================================================================
# PostgreSQL Database Backup Script
# ============================================================================
# This script backs up the PostgreSQL database to S3
# Run daily via cron: 0 2 * * * /home/ec2-user/app/backup-database.sh
# ============================================================================

set -e  # Exit on error

# Configuration
BACKUP_DIR="/tmp/db-backups"
S3_BUCKET="codedetect-nick-uploads-12345"
S3_PREFIX="database-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="codedetect_backup_${DATE}.sql.gz"
RETENTION_DAYS=30  # Keep backups for 30 days

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}PostgreSQL Backup Script${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Step 1: Dump PostgreSQL database
echo -e "${YELLOW}📦 Creating database dump...${NC}"
docker exec codedetect-postgres pg_dump -U codedetect codedetect | gzip > "$BACKUP_DIR/$BACKUP_FILE"

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    echo -e "${GREEN}✅ Database dump created: $BACKUP_FILE (${BACKUP_SIZE})${NC}"
else
    echo -e "${RED}❌ Database dump failed!${NC}"
    exit 1
fi

# Step 2: Upload to S3
echo ""
echo -e "${YELLOW}☁️  Uploading to S3...${NC}"
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE" "s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE" --region eu-west-1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Uploaded to S3: s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE${NC}"
else
    echo -e "${RED}❌ S3 upload failed!${NC}"
    exit 1
fi

# Step 3: Clean up old local backups
echo ""
echo -e "${YELLOW}🧹 Cleaning up local backups...${NC}"
find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +7 -delete
echo -e "${GREEN}✅ Deleted local backups older than 7 days${NC}"

# Step 4: Clean up old S3 backups (older than $RETENTION_DAYS)
echo ""
echo -e "${YELLOW}🗑️  Cleaning up old S3 backups...${NC}"
CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" --region eu-west-1 | while read -r line; do
    BACKUP_DATE=$(echo "$line" | awk '{print $1}')
    BACKUP_NAME=$(echo "$line" | awk '{print $4}')

    if [[ "$BACKUP_DATE" < "$CUTOFF_DATE" ]]; then
        echo "  Deleting old backup: $BACKUP_NAME (from $BACKUP_DATE)"
        aws s3 rm "s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_NAME" --region eu-west-1
    fi
done
echo -e "${GREEN}✅ Deleted S3 backups older than $RETENTION_DAYS days${NC}"

# Step 5: Verify backup integrity
echo ""
echo -e "${YELLOW}🔍 Verifying backup integrity...${NC}"
gunzip -t "$BACKUP_DIR/$BACKUP_FILE"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup file is valid${NC}"
else
    echo -e "${RED}❌ Backup file is corrupted!${NC}"
    exit 1
fi

# Step 6: Send SNS notification (optional)
echo ""
echo -e "${YELLOW}📧 Sending backup notification...${NC}"
SNS_TOPIC_ARN="arn:aws:sns:eu-west-1:772297676546:codedetect-prod-alerts"
aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "CodeDetect Database Backup - Success" \
    --message "Database backup completed successfully.

Backup Details:
- File: $BACKUP_FILE
- Size: $BACKUP_SIZE
- Location: s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE
- Date: $(date)

This is an automated backup notification." \
    --region eu-west-1 > /dev/null 2>&1

# Summary
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Backup Complete! ✅${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "Backup file: ${BACKUP_FILE}"
echo -e "Size: ${BACKUP_SIZE}"
echo -e "Location: s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE"
echo ""
