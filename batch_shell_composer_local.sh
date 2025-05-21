#!/bin/bash

#!/bin/bash

BASE_DIR="/www/wwwroot"
LOG_FILE="/var/log/local_composer_update.log"

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
    local dir=$1
    log "Running composer update in $dir"

    echo -e "${YELLOW}Updating $dir...${NC}"

    cd "$BASE_DIR/$dir" || { error "Failed to change directory to $BASE_DIR/$dir"; return 1; }
    rm composer.lock
    git pull || { log "Git pull failed in $dir"; send_feishu_notification "Git pull failed in $dir"; return 1; }
    composer update --no-interaction || { log "Composer update failed in $dir"; send_feishu_notification "Composer update failed in $dir"; return 1; }

    php artisan migrate || { log "Failed to run migrations in $dir"; send_feishu_notification "Failed to run migrations in $dir"; return 1; }

    echo -e "${GREEN}Composer update completed in $dir${NC}"
}

# Execute composer update in Apps/Apis directory
execute_composer_update_api() {
    local dir=$1
    log "Running composer update in $dir"

    echo -e "${YELLOW}Updating $dir...${NC}"

    # check if the directory exists
    if [ ! -d "$BASE_DIR/$dir" ]; then
        log "Directory $BASE_DIR/$dir does not exist"
        return
    fi

    cd "$BASE_DIR/$dir" || error "Failed to change directory to $BASE_DIR/$dir"
    git pull || error "Git pull failed in $dir"

    echo -e "${GREEN}Composer update completed in $dir${NC}"
}

# Send Feishu notification
send_feishu_notification() {
    local message=$1
    log "Sending Feishu notification: $message"

    server_ip=$(hostname -I | awk '{print $1}')

    # message add server ip
    message="$message Server IP: $server_ip"

    curl -X POST -H "Content-Type: application/json" -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"$message\"}}" https://open.feishu.cn/open-apis/bot/v2/hook/054d1cae-c463-4200-ad83-4bea82bd07d6
}


# Main execution
main() {
    log "Starting local composer update process"

    # Find directories starting with 'api.'
    api_dirs=$(find "$BASE_DIR" -maxdepth 1 -type d -name '*api.*' -printf '%f\n')

    if [ -z "$api_dirs" ]; then
        log "No directories found starting with 'api.'"
        exit 0
    fi

    for dir in $api_dirs; do
        execute_composer_update "$dir"
    done

    # Execute composer update in Apps/Apis
    execute_composer_update_api "Apps/Apis"

    # get the server ipv4 address use hostname -I
    server_ip=$(hostname -I | awk '{print $1}')
    #server_ip=$(curl -s ifconfig.me)
    # send notification to feishu with the server ip
    curl -X POST -H "Content-Type: application/json" -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"Local composer update process completed on $server_ip\"}}" https://open.feishu.cn/open-apis/bot/v2/hook/054d1cae-c463-4200-ad83-4bea82bd07d6
    #curl -X POST -H "Content-Type: application/json" -d '{"msg_type":"text","content":{"text":"Local composer update process completed"}}' https://open.feishu.cn/open-apis/bot/v2/hook/054d1cae-c463-4200-ad83-4bea82bd07d6

    log "Local composer update process completed"
}

# Run main
main
