#!/bin/bash

THRESHOLD_KB=$((250 * 1024 * 1024)) # 250GB in KB
MOUNT=/mnt/backup
LOGFILE=/var/log/backup-space.log

now() {
    date +'%Y-%m-%d %H:%M:%S'
}

# Only run if external is mounted
if ! mountpoint -q "$MOUNT"; then
    echo "$(now): external not mounted, skipping check" >> "$LOGFILE"
    exit 0
fi

AVAILABLE=$(df "$MOUNT" | awk 'NR==2 {print $4}')

if [ "$AVAILABLE" -lt "$THRESHOLD_KB" ]; then
    echo "$(now): WARNING - backup drive under 250GB remaining" >> "$LOGFILE"
else
    # Clear the log file if space is fine
    > "$LOGFILE"
fi
