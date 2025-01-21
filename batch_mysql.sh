#!/bin/bash

SERVERS=(
    "172.104.152.86"
    "172.233.49.80"
    "45.79.79.208"
)

DB=(
    "api_hatme_net"
    "api_kundies_cz"
    "api_kundies_pl"
    "api_mqqhot_com"
    "api_othshoe_cz"
    "api_othshoe_pl"
    "api_sedyes_com"
    "api_tdtopic_com"
    "api_wmbh_net"
    "api_hatmeo_com"
    "api_hatmeo_net"
    "api_hautotool_co"
    "api_kundies_com"
    "api_othshoe_com"
    "api_wmet_net"
    "api_wngift_com"
    "api_botma_fr"
    "api_gofrei_de"
    "api_hatme_de"
    "api_hautotool_de"
    "api_kundies_de"
    "api_othshoe_de"
    "api_othshoe_uk"
    "api_wmbh_uk"
    "api_wmbrashop_co"
    "api_wmbra_de"
    "api_wmbra_uk"
    "api_wmcer_com"
    "api_wngift_de"
    "api_yooje_uk"
    "shop_kundies_com"
)

BASE_DIR="/www/wwwroot"
LOG_FILE="/var/log/composer_update.log"

DB_HOST="127.0.0.1"
DB_USER="steven"
DB_PASS="Z19aMpbacka6w5Q9ZkcR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "${GREEN}[LOG]${NC} $1"
}

# Error handling
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    exit 1
}

# Function to sync user.sql to every database
sync_user_sql() {
    local server=$1
    local sql_file=$2
    local db_name=$3
    log "Syncing $sql_file to database on $server"

    echo -e "${YELLOW}Server: ${server}${NC}"

    echo -e "${YELLOW}Syncing $sql_file to database on $server...${NC}"

    # Sync the SQL file to the server
    scp "$sql_file" root@$server:/www/wwwroot/sql.sql || error "Failed to copy $sql_file to $server"
    echo -e "${GREEN}SQL file copied to $server${NC}"

     # Check if the database exists
    ssh root@$server "mysql -h $DB_HOST -u $DB_USER -p'$DB_PASS' -e 'USE $db_name'" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "Database $db_name does not exist on $server. Skipping..."
        return
    fi


    ssh root@$server "mysql -h $DB_HOST -u $DB_USER -p'$DB_PASS' $db_name < $sql_file" || error "Failed to sync $sql_file on $server"
}

# Main script execution
for server in "${SERVERS[@]}"; do
    for db in "${DB[@]}"; do
        sync_user_sql "$server" "$BASE_DIR/sql.sql" "$db"
        # exit 0
    done
done