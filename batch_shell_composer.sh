#!/bin/bash

SERVERS=(
    "45.79.79.208"
    "172.104.152.86"
    "172.233.49.80"
)

BASE_DIR="/www/wwwroot"
LOG_FILE="/var/log/composer_update.log"

LOCKFILE="/tmp/batch_shell_composer.lock"

STATE_FILE="/tmp/composer_update_state.txt"
ABORT_FLAG="/tmp/composer_update_abort.flag"

# Check if the script is already running
if [ -e "$LOCKFILE" ]; then
    echo "Script is already running."
    exit 1
fi

# Create a lock file
touch "$LOCKFILE"

# Ensure the lock file is removed on script exit
trap 'rm -f "$LOCKFILE"' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to save the current state
save_state() {
    local server=$1
    local dir=$2
    echo "$server $dir" > "$STATE_FILE"
    log "Saved state: server=$server, dir=$dir"
}

# Function to clear the state file
clear_state() {
    rm -f "$STATE_FILE"
    log "Cleared state file"
}

# Function to check for the abort flag
check_abort() {
    if [ -e "$ABORT_FLAG" ]; then
        log "Abort flag found. Exiting."
        clear_state
        rm -f "$LOCKFILE" #remove lock file
        exit 1
    fi
}

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

    check_abort # Check for abort before starting

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
        ssh -n "$server" "cd ${BASE_DIR}/${dir} && git config --global --add safe.directory ${BASE_DIR}/${dir} && git checkout main_api && git pull && composer update" 2>&1 || {
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

    check_abort # Check for abort before starting

    log "Running php artisan migrate in ${BASE_DIR}/${dir} on $server"
    ssh root@$server "cd ${BASE_DIR}/${dir} && php artisan migrate" || error "Artisan migrate failed on $server"
}

# Process each API directory
process_api_dirs() {
    local server=$1
    log "Processing API directories on $server"
    
    echo -e "${YELLOW}Server: ${server}${NC} {BASE_DIR: ${BASE_DIR}}"
    
    # Get list of API directories
    api_dirs=$(ssh -n "$server" "cd ${BASE_DIR} && find . -maxdepth 1 -type d -name 'api.*' -printf '%f\n'") || {
        error "Failed to list directories on $server"
    }
    
    # Process each directory
    for dir in $api_dirs; do

        check_abort # Check for abort before each directory

        echo -e "${YELLOW}Processing ${dir}...${NC}"
        save_state "$server" "$dir" # Save state before processing

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
        check_abort # Check for abort before each server
        process_api_dirs "$server"
    done
    
    log "Batch processing completed"
    clear_state # Clear state after completion
}

# Main execution
main() {
     log "Starting composer update process"

    # Check for existing state and check the the shell script is not already running
    

    if [ -f "$STATE_FILE" ]; then
        log "Resuming from previous state"
        read -r server_resume dir_resume < "$STATE_FILE"
        log "Resuming from server: $server_resume, dir: $dir_resume"

        # Find the server and directory in the lists and resume from there
        resumed=false
        for server in "${SERVERS[@]}"; do
            log "Checking server: $server"
            log "Checking server_resume: $server_resume"
            if [ "$server" = "$server_resume" ]; then
                api_dirs=$(ssh -n "$server" "cd ${BASE_DIR} && find . -maxdepth 1 -type d -name 'api.*' -printf '%f\n'") || {
                    error "Failed to list directories on $server"
                }
                for dir in $api_dirs; do
                    if [ "$dir" = "$dir_resume" ]; then
                        resumed=true
                        echo -e "${YELLOW}Resuming Processing ${dir}...${NC}"
                        execute_composer_update "$server" "$dir"
                        echo "----------------------------------------"
                        echo -e "${YELLOW}Processing Migrate ${dir}...${NC}"
                        run_artisan_migrate "$server" "$dir"
                    elif $resumed = true; then
                        echo -e "${YELLOW}Processing ${dir}...${NC}"
                        execute_composer_update "$server" "$dir"
                        echo "----------------------------------------"
                        echo -e "${YELLOW}Processing Migrate ${dir}...${NC}"
                        run_artisan_migrate "$server" "$dir"
                    fi
                done
            fi
        done
    else
        batch_process
    fi
}

# Run main
main