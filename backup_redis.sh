#!/bin/bash

# Backup Redis databases
# This script will backup all Redis databases to a specified directory
# The backup files will be named "redis_db_<db_number>.rdb"
# The script will also compress the backup files using gzip

# Directory to store the backup files
BACKUP_DIR="/var/backups/redis"
DATE = $(date '+%Y-%m-%d')

# Check if the backup directory exists, create it if it doesn't
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

redis-cli --rdb "$BACKUP_DIR/redis_backup_$DATE.rdb"

gzip "$BACKUP_DIR/redis_backup_$DATE.rdb"
echo "Redis backup completed"
exit 0