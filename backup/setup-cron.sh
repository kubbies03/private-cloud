#!/bin/bash
# Install cron jobs for backup and maintenance
set -e

PROJECT_DIR="/opt/private-cloud"

echo "[CRON] Installing cron jobs..."

# Write all cron jobs at once
crontab -l 2>/dev/null > /tmp/existing_cron || true

cat >> /tmp/existing_cron <<EOF

# ─── Private Cloud Lab Automation ───────────────────────────
# Backup — daily at 02:00
0 2 * * * /bin/bash ${PROJECT_DIR}/backup/backup.sh >> /var/log/backup.log 2>&1

# Docker cleanup — weekly Sunday at 03:00
0 3 * * 0 docker system prune -f >> /var/log/docker-cleanup.log 2>&1

# Log rotation — weekly Sunday at 04:00
0 4 * * 0 find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \;

# dnsmasq health check — every 5 minutes
*/5 * * * * systemctl is-active dnsmasq > /dev/null || systemctl restart dnsmasq
EOF

crontab /tmp/existing_cron
rm /tmp/existing_cron

echo "[CRON] Installed jobs:"
crontab -l | grep -v "^#" | grep -v "^$"

echo "[CRON] Done."
