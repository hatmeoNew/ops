#!/bin/bash

# Backup Redis databases
# This script will backup all Redis databases to a specified directory
# The backup files will be named "redis_db_<db_number>.rdb"
# The script will also compress the backup files using gzip

# Directory to store the backup files
BACKUP_DIR="/var/backups/redis"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Check if the backup directory exists, create it if it doesn't
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

redis-cli --rdb "$BACKUP_DIR/redis_backup_$DATE.rdb"

gzip "$BACKUP_DIR/redis_backup_$DATE.rdb"
echo "Redis backup completed"

# Backup file to remote storage linode_object_storage_config
access_key="OJIPNNJA2RLZL4ZFXYZM"
secret_key="qywoXKhPUG7NdDcBTzK6wTPWJHfgOl1dd3g7vrGQ"
cluster_url="https://eu-central-1.linodeobjects.com"
region="eu-central-1"
bucket="img.kundies.com"

# Install MinIO client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc /usr/local/bin

# Upload the backup file to Linode Object Storage
mc alias set linode $cluster_url $access_key $secret_key

mc cp "$BACKUP_DIR/redis_backup_$DATE.rdb.gz" "linode/$bucket/redis_backup_$DATE.rdb.gz"

echo "Backup file uploaded to Linode Object Storage"

exit 0