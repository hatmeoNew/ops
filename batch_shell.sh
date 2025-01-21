#!/bin/bash

# Config - Server List
SERVERS=(
    "172.233.49.80"
    "45.79.79.208"
    "172.104.152.86"
)

DIRS="/www/wwwroot/"

# Log file
LOG_FILE="/var/log/batch_commands.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# Execute command on single server
execute_command() {
    local server=$1
    local command=$2
    log "Executing on $server: $command"
    
    ssh -n "$server" "$command" 2>&1 || {
        error "Failed to execute command on $server"
    }
}

# Execute command on all servers in parallel
batch_execute() {
    local command=$1
    
    for server in "${SERVERS[@]}"; do
        (execute_command "$server" "$command") &
    done
    
    # Wait for all background processes
    wait
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        error "Usage: $0 'command to execute'"
    fi

    log "Starting batch execution"
    batch_execute "$1"
    log "Batch execution completed"
}

# Run main with all arguments
main "$@"