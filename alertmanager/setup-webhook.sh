#!/bin/bash
# Run this after setting SLACK_WEBHOOK_URL in .env
# Usage: bash alertmanager/setup-webhook.sh

set -e
source "$(dirname "$0")/../.env" 2>/dev/null || true

if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
    echo "ERROR: SLACK_WEBHOOK_URL not set in .env"
    echo "Edit .env and set: SLACK_WEBHOOK_URL=https://hooks.slack.com/services/..."
    exit 1
fi

CONFIG="$(dirname "$0")/alertmanager.yml"
sed -i "s|'\${SLACK_WEBHOOK_URL}'|'${SLACK_WEBHOOK_URL}'|g" "$CONFIG"
echo "Webhook URL configured in alertmanager.yml"

# Reload alertmanager
docker compose restart alertmanager 2>/dev/null && echo "Alertmanager restarted" || true
