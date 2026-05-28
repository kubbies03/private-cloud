#!/bin/bash
# Master deploy script — run once on fresh Ubuntu Server VM
# Usage: sudo bash deploy.sh
set -euo pipefail

PROJECT_DIR="/opt/private-cloud"
REPO_URL=""   # Fill in if using git clone

log()  { echo -e "\n\033[1;32m[DEPLOY]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
die()  { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

[ "$EUID" -eq 0 ] || die "Run as root: sudo bash deploy.sh"

# ─── Step 1: System update ───────────────────────────────────
log "1/8 Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq

# ─── Step 2: Install dependencies ────────────────────────────
log "2/8 Installing dependencies..."
apt-get install -y -qq \
    curl wget git vim htop \
    ca-certificates gnupg lsb-release \
    openssl net-tools dnsutils \
    python3 python3-pip

# ─── Step 3: Install Docker ──────────────────────────────────
log "3/8 Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
    usermod -aG docker "${SUDO_USER:-ubuntu}"
    systemctl enable docker
    systemctl start docker
    log "Docker installed."
else
    log "Docker already installed: $(docker --version)"
fi

# ─── Step 4: Copy project files ──────────────────────────────
log "4/8 Setting up project directory..."
mkdir -p "$PROJECT_DIR"

if [ -d "$(pwd)/nginx" ]; then
    cp -r "$(pwd)/." "$PROJECT_DIR/"
    log "Project files copied to $PROJECT_DIR"
else
    warn "Run this script from the project directory, or set REPO_URL"
fi

chmod +x "$PROJECT_DIR"/scripts/*.sh
chmod +x "$PROJECT_DIR"/backup/*.sh
chmod +x "$PROJECT_DIR"/dns/setup-dns.sh
chmod +x "$PROJECT_DIR"/nginx/ssl/gen-cert.sh

# ─── Step 5: Generate SSL cert ───────────────────────────────
log "5/8 Generating self-signed SSL certificate..."
cd "$PROJECT_DIR/nginx/ssl"
bash gen-cert.sh
cd "$PROJECT_DIR"

# ─── Step 6: Setup DNS ───────────────────────────────────────
log "6/8 Setting up internal DNS (dnsmasq)..."

# Auto-detect primary network interface and patch dnsmasq.conf
PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}' | head -1)
if [ -n "$PRIMARY_IFACE" ] && [ "$PRIMARY_IFACE" != "ens33" ]; then
    log "Detected interface: $PRIMARY_IFACE (updating dnsmasq.conf from ens33)"
    sed -i "s/interface=ens33/interface=${PRIMARY_IFACE}/" "$PROJECT_DIR/dns/dnsmasq.conf"
else
    log "Using interface: ${PRIMARY_IFACE:-ens33}"
fi

bash "$PROJECT_DIR/dns/setup-dns.sh"

# ─── Step 7: Security hardening ──────────────────────────────
log "7/8 Applying security hardening..."

# SSH key — warn if not set up
if [ ! -f /home/"${SUDO_USER:-ubuntu}"/.ssh/authorized_keys ]; then
    warn "No SSH authorized_keys found. Set up SSH key BEFORE running hardening!"
    warn "Skipping SSH hardening — run manually: bash $PROJECT_DIR/scripts/security-hardening.sh"
else
    bash "$PROJECT_DIR/scripts/security-hardening.sh"
fi

# ─── Step 8: Start services ──────────────────────────────────
log "8/8 Starting all services with Docker Compose..."
cd "$PROJECT_DIR"

# Create .env from example if not present
if [ ! -f "$PROJECT_DIR/.env" ]; then
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    warn ".env created from .env.example — review SECRET_KEY and GRAFANA_PASSWORD before going to production"
fi

docker compose pull
docker compose up -d

# Wait for services
sleep 10

# ─── Setup cron ──────────────────────────────────────────────
log "Setting up cron jobs..."
bash "$PROJECT_DIR/backup/setup-cron.sh"

# ─── Final status ────────────────────────────────────────────
log "=== Deployment complete! ==="
echo ""
echo "Services:"
docker compose ps
echo ""
echo "Access URLs (add to /etc/hosts or use internal DNS):"
echo "  https://api.lab.local        → FastAPI Enterprise App"
echo "  https://grafana.lab.local    → Grafana Dashboard"
echo "  https://prometheus.lab.local → Prometheus"
echo ""
echo "Grafana credentials: admin / admin123"
echo "API users: admin/admin123, operator/operator123, viewer/viewer123"
echo ""
echo "Next steps:"
echo "  1. Set up Windows Server VM (AD + SMB)"
echo "  2. Add DNS entries for Windows VM"
echo "  3. Take screenshots for CV demo"
