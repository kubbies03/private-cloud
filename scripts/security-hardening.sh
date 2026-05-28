#!/bin/bash
# Security hardening for Ubuntu Infra VM
# Run as root after initial OS install
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] [SECURITY] $1"; }

# ─── UFW Firewall ─────────────────────────────────────────────
log "Configuring UFW firewall..."

apt-get install -y ufw

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow 22/tcp comment "SSH"

# HTTP/HTTPS (Nginx)
ufw allow 80/tcp  comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# DNS (dnsmasq — internal only)
ufw allow from 192.168.159.0/24 to any port 53 comment "DNS internal"

# Monitoring ports — internal network only
ufw allow from 192.168.159.0/24 to any port 9090 comment "Prometheus internal"
ufw allow from 192.168.159.0/24 to any port 3000 comment "Grafana internal"
ufw allow from 192.168.159.0/24 to any port 3100 comment "Loki internal"
ufw allow from 192.168.159.0/24 to any port 9100 comment "Node Exporter internal"

ufw --force enable
log "UFW status:"
ufw status verbose

# ─── SSH Hardening ───────────────────────────────────────────
log "Hardening SSH..."

SSH_CONFIG="/etc/ssh/sshd_config"
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d)"

cat > /etc/ssh/sshd_config.d/hardening.conf <<EOF
# SSH Hardening — Private Cloud Lab
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
X11Forwarding no
AllowTcpForwarding no
PermitEmptyPasswords no
ClientAliveInterval 300
ClientAliveCountMax 2
Protocol 2
EOF

systemctl restart sshd
log "SSH hardened."

# ─── Fail2Ban ────────────────────────────────────────────────
log "Installing and configuring Fail2Ban..."

apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ssh
filter   = sshd
maxretry = 3
bantime  = 24h

[nginx-http-auth]
enabled  = true
port     = http,https
filter   = nginx-http-auth
logpath  = /var/log/nginx/error.log
maxretry = 5

[nginx-limit-req]
enabled  = true
port     = http,https
filter   = nginx-limit-req
logpath  = /var/log/nginx/error.log
maxretry = 10
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log "Fail2Ban active."

# ─── Kernel hardening (sysctl) ────────────────────────────────
log "Applying kernel hardening..."

cat > /etc/sysctl.d/99-lab-hardening.conf <<EOF
# NOTE: Keep IP forwarding ON — Docker requires it for container networking
# net.ipv4.ip_forward = 1  (Docker sets this automatically)

# Ignore ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
EOF

sysctl -p /etc/sysctl.d/99-lab-hardening.conf
log "Kernel hardening applied."

# ─── Auto security updates ────────────────────────────────────
log "Enabling unattended security upgrades..."

apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades || true

log "=== Security hardening complete ==="
log "Summary:"
log "  - UFW: enabled, ports 22/80/443 open"
log "  - SSH: root login disabled, password auth disabled"
log "  - Fail2Ban: SSH + Nginx protection active"
log "  - Kernel: SYN flood protection, source routing disabled"
