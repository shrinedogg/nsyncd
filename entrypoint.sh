#!/bin/bash

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting syncoid container..."

# Check SSH key exists (permissions set via secret defaultMode)
if [ -f /root/.ssh/id_rsa ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH key configured"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: SSH key not found at /root/.ssh/id_rsa"
fi

# Export SSH options to disable host key checking (avoids writing to known_hosts)
export SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Run initial sync if requested
if [ "${RUN_ON_START:-false}" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running initial sync..."
    /usr/local/bin/sync.sh || echo "[$(date '+%Y-%m-%d %H:%M:%S')] Initial sync failed, will retry on schedule"
fi

# Start cron daemon in foreground
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting cron daemon..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sync scheduled to run every 15 minutes"

# Run cron in foreground mode (logs go to stdout)
exec cron -f
