#!/bin/bash

SERVERS=(
    "172.104.152.86"
    "172.233.49.80"
    "45.79.79.208"
)

BASE_DIR="/www/wwwroot"
LOG_FILE="/var/log/composer_update.log"

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

# Execute composer update in directory
execute_composer_update() {
    local server=$1
    local dir=$2
    log "Running composer update in $dir on $server"

    echo -e "${YELLOW}Server: ${server}${NC}"

    echo -e "${YELLOW}Updating $dir...${NC}"

    # Check if the Apis directory exists
    if ssh -n "$server" "[ -d ${BASE_DIR}/Apps/Apis ]"; then
        echo -e "${YELLOW}Executing composer update in $dir on $server${NC}"
        ssh -n "$server" "cd ${BASE_DIR}/Apps/Apis/ && git pull && cd ${BASE_DIR}/${dir} && git config --global --add safe.directory ${BASE_DIR}/${dir} && git pull && composer update" 2>&1 || {
            error "Composer update failed in $dir on $server"
        }
    else
        echo -e "${YELLOW}Executing composer update in $dir on $server without Apis directory${NC}"
        ssh -n "$server" "cd ${BASE_DIR}/${dir} && git config --global --add safe.directory ${BASE_DIR}/${dir} && git pull && composer update" 2>&1 || {
            error "Composer update failed in $dir on $server"
        }
    fi

    echo -e "${YELLOW}Executing composer update in $dir on $server${NC}"
    
    # ssh -n "$server" "cd ${BASE_DIR}/Apps/Apis/ && git pull && cd ${BASE_DIR}/${dir} && git config --global --add safe.directory ${BASE_DIR}/${dir} && git pull && composer update" 2>&1 || {
    #     error "Composer update failed in $dir on $server"
    # }

    echo -e "${GREEN}Composer update completed in $dir on $server${NC}"

    echo "----------------------------------------"
    # wait for 5 seconds
    sleep 5
}

# Run php artisan migrate
run_artisan_migrate() {
    local server=$1
    local dir=$2
    log "Running php artisan migrate in ${BASE_DIR}/${dir} on $server"
    ssh root@$server "cd ${BASE_DIR}/${dir} && php artisan migrate" || error "Artisan migrate failed on $server"
}

# Process each API directory
process_api_dirs() {
    local server=$1
    log "Processing API directories on $server"
    
    echo -e "${YELLOW}Server: ${server}${NC}"
    
    # Get list of API directories
    api_dirs=$(ssh -n "$server" "cd ${BASE_DIR} && find . -maxdepth 1 -type d -name 'api*' -printf '%f\n'") || {
        error "Failed to list directories on $server"
    }
    
    # Process each directory
    for dir in $api_dirs; do
        echo -e "${YELLOW}Processing ${dir}...${NC}"
        execute_composer_update "$server" "$dir"
        echo "----------------------------------------"
        echo -e "${YELLOW}Processing Migrate ${dir}...${NC}"
        run_artisan_migrate "$server" "$dir"
    done
}

# Execute on all servers
batch_process() {
    log "Starting batch processing"
    
    for server in "${SERVERS[@]}"; do
        process_api_dirs "$server"
    done
    
    log "Batch processing completed"
}

# Main execution
main() {
    log "Starting composer update process"
    batch_process
}

# Run main
main