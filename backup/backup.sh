#!/bin/bash
# Automated backup script — runs daily via cron
set -euo pipefail

BACKUP_DIR="/opt/backups"
PROJECT_DIR="/opt/private-cloud"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${DATE}.tar.gz"
LOG_FILE="/var/log/backup.log"
RETAIN_DAYS=7

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Backup started ==="

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# ─── Stop nothing — backup live configs only ─────────────────
log "Backing up configs and project files..."

tar -czf "$BACKUP_FILE" \
    --exclude="$PROJECT_DIR/.git" \
    --exclude="$PROJECT_DIR/nginx/ssl/*.key" \
    "$PROJECT_DIR/docker-compose.yml" \
    "$PROJECT_DIR/nginx/" \
    "$PROJECT_DIR/prometheus/" \
    "$PROJECT_DIR/loki/" \
    "$PROJECT_DIR/promtail/" \
    "$PROJECT_DIR/grafana/provisioning/" \
    "$PROJECT_DIR/fastapi/" \
    "$PROJECT_DIR/dns/" \
    "$PROJECT_DIR/backup/" \
    "$PROJECT_DIR/scripts/" \
    2>/dev/null || true

BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Config backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# ─── Docker volumes backup ───────────────────────────────────
log "Backing up Docker volumes..."

VOLUME_BACKUP="${BACKUP_DIR}/volumes_${DATE}.tar.gz"

docker run --rm \
    -v prometheus-data:/data/prometheus:ro \
    -v grafana-data:/data/grafana:ro \
    -v loki-data:/data/loki:ro \
    -v uploads-data:/data/uploads:ro \
    -v "${BACKUP_DIR}:/backup" \
    alpine:3.19 \
    tar -czf "/backup/$(basename $VOLUME_BACKUP)" \
        -C /data . 2>/dev/null || log "Warning: Volume backup skipped (Docker not running)"

log "Volume backup: $VOLUME_BACKUP"

# ─── Cleanup old backups ─────────────────────────────────────
log "Removing backups older than ${RETAIN_DAYS} days..."
find "$BACKUP_DIR" -name "backup_*.tar.gz"  -mtime +$RETAIN_DAYS -delete
find "$BACKUP_DIR" -name "volumes_*.tar.gz" -mtime +$RETAIN_DAYS -delete

REMAINING=$(ls "$BACKUP_DIR" | wc -l)
log "Remaining backup files: $REMAINING"

log "=== Backup completed successfully ==="
