#!/bin/bash

# Syncoid sync script
# Runs syncoid to replicate remote ZFS pool to local NFS-mounted pool

set -e

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo "${LOG_PREFIX} Starting syncoid sync..."

# Environment variables with defaults
REMOTE_USER="${REMOTE_USER}"
REMOTE_HOST="${REMOTE_HOST}"
REMOTE_PORT="${REMOTE_PORT}"
REMOTE_DATASET="${REMOTE_DATASET}"
LOCAL_DATASET="${LOCAL_DATASET}"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_rsa}"
SSH_CIPHER="${SSH_CIPHER:-chacha20-poly1305@openssh.com}"
MBUFFER_SIZE="${MBUFFER_SIZE:-1G}"

# Stall detection settings
STALL_THRESHOLD="${STALL_THRESHOLD:-5}"
RATE_THRESHOLD="${RATE_THRESHOLD:-1000}"
MAX_RETRIES="${MAX_RETRIES:-3}"

# SSH options for read-only filesystem (no known_hosts writes)
SSH_OPTIONS="${SSH_OPTIONS:--o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"

retry_count=0

while [ $retry_count -lt $MAX_RETRIES ]; do
    echo "${LOG_PREFIX} Attempt $((retry_count + 1)) of ${MAX_RETRIES}"
    
    # Run syncoid
    if syncoid \
        --no-privilege-elevation \
        --sshport="${REMOTE_PORT}" \
        --sshkey="${SSH_KEY}" \
        --sshcipher="${SSH_CIPHER}" \
        --sshoption="StrictHostKeyChecking=no" \
        --sshoption="UserKnownHostsFile=/dev/null" \
        --mbuffer-size="${MBUFFER_SIZE}" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DATASET}" \
        "${LOCAL_DATASET}"; then
        
        echo "${LOG_PREFIX} Sync completed successfully!"
        exit 0
    else
        exit_code=$?
        echo "${LOG_PREFIX} Sync failed with exit code: ${exit_code}"
        retry_count=$((retry_count + 1))
        
        if [ $retry_count -lt $MAX_RETRIES ]; then
            echo "${LOG_PREFIX} Waiting 10 seconds before retry..."
            sleep 10
        fi
    fi
done

echo "${LOG_PREFIX} All retry attempts exhausted. Sync failed."
exit 1
