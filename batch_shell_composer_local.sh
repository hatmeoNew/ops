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
    git config --global --add safe.directory "$BASE_DIR/$dir"
    git pull || error "Git pull failed in $dir"
    composer update -vvv --no-interaction || error "Composer update failed in $dir"

    php artisan migrate || error "Failed to run migrations in $dir"

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

    log "Local composer update process completed"
}

# Run main
main