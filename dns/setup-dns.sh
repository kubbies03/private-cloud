#!/bin/bash
# Install and configure dnsmasq on Ubuntu Infra VM
set -e

echo "[DNS] Installing dnsmasq..."
apt-get update -qq
apt-get install -y dnsmasq

echo "[DNS] Disabling systemd-resolved stub listener..."
# Set DNSStubListener=no so port 53 is freed for dnsmasq
sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
if ! grep -q "^DNSStubListener=no" /etc/systemd/resolved.conf; then
    echo "DNSStubListener=no" >> /etc/systemd/resolved.conf
fi
systemctl restart systemd-resolved

echo "[DNS] Copying dnsmasq config..."
cp /opt/private-cloud/dns/dnsmasq.conf /etc/dnsmasq.conf

echo "[DNS] Starting dnsmasq..."
systemctl enable dnsmasq
systemctl restart dnsmasq

echo "[DNS] Configuring DNS via systemd-resolved (survives reboot)..."
# Use resolved.conf instead of overwriting /etc/resolv.conf directly
cat >> /etc/systemd/resolved.conf <<EOF

[Resolve]
DNS=127.0.0.1
FallbackDNS=8.8.8.8
Domains=lab.local
EOF
systemctl restart systemd-resolved

# Point /etc/resolv.conf at the resolved stub (standard Ubuntu 22.04 approach)
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "[DNS] Testing resolution..."
sleep 2
nslookup api.lab.local 127.0.0.1 || echo "[WARN] DNS test failed — check dnsmasq status"
nslookup grafana.lab.local 127.0.0.1 || true

echo "[DNS] Done. Internal DNS is active."
