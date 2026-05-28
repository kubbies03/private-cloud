#!/bin/bash
# Generate demo traffic to populate Grafana dashboards
# Usage: bash scripts/seed-traffic.sh [count]
set -e

COUNT="${1:-50}"
BASE="https://localhost:8443"

echo "Getting token..."
TOKEN=$(curl -sk -X POST "${BASE}/auth/token" \
  -d "username=operator&password=operator123" | jq -r .access_token)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "ERROR: Could not get token. Is the stack running?"
    exit 1
fi

echo "Generating $COUNT requests..."

for i in $(seq 1 "$COUNT"); do
    # Health check (no auth)
    curl -sk "${BASE}/health" > /dev/null

    # Authenticated endpoints
    curl -sk -H "Authorization: Bearer $TOKEN" "${BASE}/" > /dev/null
    curl -sk -H "Authorization: Bearer $TOKEN" "${BASE}/info" > /dev/null
    curl -sk -H "Authorization: Bearer $TOKEN" "${BASE}/dashboard" > /dev/null

    # Upload a small file every 5 requests
    if (( i % 5 == 0 )); then
        echo "seed-file-${i}" > /tmp/seed-${i}.txt
        curl -sk -X POST "${BASE}/files/upload" \
          -H "Authorization: Bearer $TOKEN" \
          -F "file=@/tmp/seed-${i}.txt" > /dev/null
        rm -f /tmp/seed-${i}.txt
        echo "  [$i/$COUNT] uploaded file"
    else
        echo "  [$i/$COUNT]"
    fi

    sleep 0.3
done

echo ""
echo "Done. Metrics visible at:"
echo "  Grafana:    http://192.168.159.131:3001"
echo "  Prometheus: http://192.168.159.131:9091"
