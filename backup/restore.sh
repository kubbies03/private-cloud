#!/bin/bash
# Restore from backup
set -euo pipefail

BACKUP_DIR="/opt/backups"
PROJECT_DIR="/opt/private-cloud"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <backup_date>"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null || echo "  No backups found"
    exit 1
fi

DATE="$1"
BACKUP_FILE="${BACKUP_DIR}/backup_${DATE}.tar.gz"
VOLUME_FILE="${BACKUP_DIR}/volumes_${DATE}.tar.gz"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup not found: $BACKUP_FILE"
    exit 1
fi

log "=== Restore started from $DATE ==="

log "Stopping services..."
cd "$PROJECT_DIR"
docker compose down || true

log "Restoring configs from $BACKUP_FILE..."
tar -xzf "$BACKUP_FILE" -C / 2>/dev/null

if [ -f "$VOLUME_FILE" ]; then
    log "Restoring Docker volumes from $VOLUME_FILE..."
    docker run --rm \
        -v prometheus-data:/data/prometheus \
        -v grafana-data:/data/grafana \
        -v loki-data:/data/loki \
        -v "${BACKUP_DIR}:/backup:ro" \
        alpine:3.19 \
        tar -xzf "/backup/$(basename $VOLUME_FILE)" -C /data
fi

log "Restarting services..."
docker compose up -d

log "=== Restore completed ==="
