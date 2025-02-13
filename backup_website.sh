#!/bin/bash

#Variables
BACKUP_DIR="/www/wwwroot/backup"
DB_NAME="api_hautotool_co"
DB_USER="root"
DB_PASSWORD="116345140a9d89e6"
DATE=$(date +%F)
PROJECT="api_hautotool_co"

REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"
REDIS_PASSWORD=""
REDIS_DBS=("12" "13" "14")
REDIS_CLI_PATH="/usr/bin/redis-cli"


# backup mysql
# Dump the MySQL database and compress it
mysqldump -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" | gzip > "$BACKUP_DIR/$DB_NAME-$DATE.sql.gz"

# Check if the backup was successful
if [ $? -eq 0 ]; then
    echo "MySQL backup successful: $BACKUP_DIR/$DB_NAME-$DATE.sql.gz"
else
    echo "MySQL backup failed"
fi

# backup redis for redis db 0

# Check if the Redis CLI exists
if [ ! -f "$REDIS_CLI_PATH" ]; then
    echo "Redis CLI not found at $REDIS_CLI_PATH"
    exit 1
fi

for REDIS_DB in "${REDIS_DBS[@]}"; do
    REDIS_DUMP_FILE="$BACKUP_DIR/redis-dump-$REDIS_DB-$DATE.rdb"

    # Save the Redis database to a dump file
    $REDIS_CLI_PATH -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB --rdb $REDIS_DUMP_FILE

    # Check if the dump was successful
    if [ $? -eq 0 ]; then
        echo "Redis backup successful: $REDIS_DUMP_FILE"
    else
        echo "Redis backup failed"
    fi
done









