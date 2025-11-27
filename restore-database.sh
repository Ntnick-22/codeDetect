#!/bin/bash
# ============================================================================
# PostgreSQL Database Restore Script
# ============================================================================
# This script restores the PostgreSQL database from S3 backup
# Usage: ./restore-database.sh [backup-filename]
# Example: ./restore-database.sh codedetect_backup_20251126_020000.sql.gz
# ============================================================================

set -e  # Exit on error

# Configuration
BACKUP_DIR="/tmp/db-backups"
S3_BUCKET="codedetect-nick-uploads-12345"
S3_PREFIX="database-backups"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}PostgreSQL Restore Script${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if backup filename provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Available backups in S3:${NC}"
    echo ""
    aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" --region eu-west-1 | awk '{print $4}'
    echo ""
    echo -e "${RED}Usage: $0 <backup-filename>${NC}"
    echo -e "${YELLOW}Example: $0 codedetect_backup_20251126_020000.sql.gz${NC}"
    exit 1
fi

BACKUP_FILE=$1

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Step 1: Download from S3
echo -e "${YELLOW}☁️  Downloading backup from S3...${NC}"
aws s3 cp "s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE" "$BACKUP_DIR/$BACKUP_FILE" --region eu-west-1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to download backup from S3${NC}"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
echo -e "${GREEN}✅ Downloaded: $BACKUP_FILE ($BACKUP_SIZE)${NC}"

# Step 2: Verify backup integrity
echo ""
echo -e "${YELLOW}🔍 Verifying backup integrity...${NC}"
gunzip -t "$BACKUP_DIR/$BACKUP_FILE"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Backup file is corrupted!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Backup file is valid${NC}"

# Step 3: Stop application (to prevent writes during restore)
echo ""
echo -e "${YELLOW}⏸️  Stopping application...${NC}"
docker-compose stop codedetect
echo -e "${GREEN}✅ Application stopped${NC}"

# Step 4: Drop existing database and recreate
echo ""
echo -e "${RED}⚠️  WARNING: This will DELETE all existing data!${NC}"
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    docker-compose start codedetect
    exit 0
fi

echo -e "${YELLOW}🗑️  Dropping existing database...${NC}"
docker exec codedetect-postgres psql -U codedetect -d postgres -c "DROP DATABASE IF EXISTS codedetect;"
docker exec codedetect-postgres psql -U codedetect -d postgres -c "CREATE DATABASE codedetect;"
echo -e "${GREEN}✅ Database recreated${NC}"

# Step 5: Restore from backup
echo ""
echo -e "${YELLOW}📥 Restoring database...${NC}"
gunzip -c "$BACKUP_DIR/$BACKUP_FILE" | docker exec -i codedetect-postgres psql -U codedetect codedetect

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Database restored successfully${NC}"
else
    echo -e "${RED}❌ Database restore failed!${NC}"
    exit 1
fi

# Step 6: Restart application
echo ""
echo -e "${YELLOW}▶️  Starting application...${NC}"
docker-compose start codedetect
sleep 5

# Step 7: Verify application health
echo ""
echo -e "${YELLOW}🔍 Checking application health...${NC}"
HEALTH_CHECK=$(curl -s http://localhost/api/health | grep -o '"status":"healthy"')
if [ -n "$HEALTH_CHECK" ]; then
    echo -e "${GREEN}✅ Application is healthy${NC}"
else
    echo -e "${RED}⚠️  Application may not be healthy, check logs${NC}"
fi

# Cleanup
rm -f "$BACKUP_DIR/$BACKUP_FILE"

# Summary
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Restore Complete! ✅${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "Restored from: ${BACKUP_FILE}"
echo -e "Database: codedetect"
echo ""
