#!/bin/bash
# filepath: /www/wwwroot/shell/restore_website.sh

MYSQL_USER="api_kundies_de"
MYSQL_PASS="XiXwwQPRQWFYfzm5"
MYSQL_DB="api_kundies_de"
MYSQL_HOST="127.0.0.1"
MYSQL_DUMP_FILE="api_kundies_com-2025-01-21.sql.gz"
TEMP_SQL_FILE="/tmp/mysql_dump.sql"

REDIS_RDB_FILE="redis-dump-12-2025-01-21.rdb"
REDIS_CLI="/usr/bin/redis-cli"
REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"
REDIS_DB="29"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}[LOG]${NC} $1"
}

# Error handling
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Restore MySQL database
restore_mysql() {
    log "Restoring MySQL database $MYSQL_DB from $MYSQL_DUMP_FILE"
    gunzip -c $MYSQL_DUMP_FILE > $TEMP_SQL_FILE || error "Failed to extract MySQL dump file"
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB < $TEMP_SQL_FILE || error "Failed to restore MySQL database"
    log "MySQL database restored successfully"
    #rm -f $TEMP_SQL_FILE

    # update the locale en to de
    # ba_attribute_translations
    #mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "UPDATE ba_attribute_translations SET locale='de' where locale='en';"
    # ba_product_flat
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "UPDATE ba_product_flat SET locale='de' where locale='en';"
    # ba_product_attribute_values
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "UPDATE ba_product_attribute_values SET locale='de' where locale='en';"
    # ba_category_translations
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "UPDATE ba_category_translations SET locale='de' where locale='en';"
    #  ba_cms_page_translations
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "UPDATE ba_cms_page_translations SET locale='de' where locale='en';"
}

# Restore Redis database
restore_redis() {
    log "Restoring Redis database $REDIS_DB from $REDIS_RDB_FILE"
    # Stop Redis server
    systemctl stop redis || error "Failed to stop Redis server"
    # Copy RDB file to Redis data directory
    cp $REDIS_RDB_FILE /var/lib/redis/dump.rdb || error "Failed to copy Redis RDB file"
    # Start Redis server
    systemctl start redis || error "Failed to start Redis server"
    # Select the specific Redis database and flush it
    $REDIS_CLI -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB FLUSHDB || error "Failed to flush Redis database"
    log "Redis database restored successfully"
}

# Confirmation prompt
confirm() {
    read -p "Are you sure you want to restore the databases? This will overwrite existing data. (yes/no): " choice
    case "$choice" in 
        yes|Yes|YES ) log "Proceeding with restore operations";;
        no|No|NO ) log "Restore operation cancelled"; exit 0;;
        * ) log "Invalid choice"; exit 1;;
    esac
}

# Main script execution
confirm
restore_mysql
#restore_redis