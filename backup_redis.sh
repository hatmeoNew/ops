#!/bin/bash

# Backup Redis databases
# This script will backup all Redis databases to a specified directory
# The backup files will be named "redis_db_<db_number>.rdb"
# The script will also compress the backup files using gzip

# Directory to store the backup files
BACKUP_DIR="/var/backups/redis"

# Check if the backup directory exists, create it if it doesn't
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Get the list of Redis databases
databases=$(redis-cli INFO keyspace | grep db | cut -d' ' -f1 | cut -d':' -f2)

# Loop through each database and backup it
for db in $databases; do
    # Backup the database
    redis-cli --rdb "$BACKUP_DIR/redis_db_$db.rdb" --db $db

    # Compress the backup file
    gzip "$BACKUP_DIR/redis_db_$db.rdb"
done

echo "Redis backup completed"
exit 0