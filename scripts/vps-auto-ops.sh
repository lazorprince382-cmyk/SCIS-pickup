#!/usr/bin/env bash
# Low-maintenance VPS checks + PM2 boot persistence (run on VPS as root).
#
#   bash scripts/vps-auto-ops.sh
#   bash scripts/vps-auto-ops.sh --install-pm2-startup

set -euo pipefail

INSTALL_PM2_STARTUP=false
[[ "${1:-}" == "--install-pm2-startup" ]] && INSTALL_PM2_STARTUP=true

echo "=== Disk ==="
df -h / /var/www 2>/dev/null || df -h /
echo ""
echo "=== Memory ==="
free -h
echo ""
echo "=== Listening app ports (should be 127.0.0.1 only) ==="
ss -tlnp | grep -E ':300[0-9]|:4000' || true
echo ""
echo "=== Services ==="
systemctl is-active scis 2>/dev/null && echo "scis (systemd): active" || echo "scis (systemd): not active"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list
else
  echo "pm2: not installed"
fi
echo ""
echo "=== PostgreSQL databases ==="
sudo -u postgres psql -tAc "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY 1;" 2>/dev/null || true
echo ""
echo "=== Nginx sites ==="
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || true

if $INSTALL_PM2_STARTUP; then
  if ! command -v pm2 >/dev/null 2>&1; then
    npm install -g pm2
  fi
  pm2 save
  pm2 startup systemd -u root --hp /root
  echo "PM2 will resurrect apps on reboot after: pm2 save"
fi

echo ""
echo "Tips:"
echo "  - Keep only ports 80/443 open publicly (ufw)."
echo "  - Each app: own folder, own .env, own Postgres DB."
echo "  - pm2 logs --lines 50   journalctl -u scis -n 50"
