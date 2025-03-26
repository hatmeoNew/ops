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

    cd "$BASE_DIR/$dir" || error "Failed to change directory to $BASE_DIR/$dir"
    git remote set-url origin git@github.com:xxl4/NexaMerchant.git
    git config --global --add safe.directory "$BASE_DIR/$dir"
    git pull || error "Git pull failed in $dir"
    composer update --no-interaction || error "Composer update failed in $dir"

    php artisan migrate || error "Failed to run migrations in $dir"

    php artisan onebuy:change-product-rule-save || error "Failed to run onebuy:change-product-rule-save in $dir"

    echo -e "${GREEN}Composer update completed in $dir${NC}"
}

# Main execution
main() {
    log "Starting local composer update process"

    # Find directories starting with 'api.'
    api_dirs=$(find "$BASE_DIR" -maxdepth 1 -type d -name 'api.*' -printf '%f\n')

    if [ -z "$api_dirs" ]; then
        log "No directories found starting with 'api.'"
        exit 0
    fi

    for dir in $api_dirs; do
        execute_composer_update "$dir"
    done

    # get the server ipv4 address
    server_ip=$(curl -s ifconfig.me)
    # send notification to feishu with the server ip
    curl -X POST -H "Content-Type: application/json" -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"Local composer update process completed on $server_ip\"}}" https://open.feishu.cn/open-apis/bot/v2/hook/054d1cae-c463-4200-ad83-4bea82bd07d6
    #curl -X POST -H "Content-Type: application/json" -d '{"msg_type":"text","content":{"text":"Local composer update process completed"}}' https://open.feishu.cn/open-apis/bot/v2/hook/054d1cae-c463-4200-ad83-4bea82bd07d6

    log "Local composer update process completed"
}

# Run main
main