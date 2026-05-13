#!/usr/bin/env bash
# Route three Node apps on one VPS IP (port 80).
#
# Defaults:
#   SCIS    -> 127.0.0.1:4000  (systemd scis)
#   Ocean   -> 127.0.0.1:3001  (pm2 ocean-school)
#   Kitchen -> 127.0.0.1:3002  (pm2 or systemd — add when ready)
#
# On VPS:
#   export OCEAN_PORT=3001
#   export KITCHEN_PORT=3002
#   bash scripts/vps-install-triple-nginx.sh
#
# Kitchen should be built to live under /kitchen/ (HTML assets, API, uploads).
# SCIS keeps /admin/, /teacher/. Ocean keeps / and /admin.html.

set -euo pipefail

SCIS_PORT="${SCIS_PORT:-4000}"
OCEAN_PORT="${OCEAN_PORT:-3001}"
KITCHEN_PORT="${KITCHEN_PORT:-3002}"
KITCHEN_PREFIX="${KITCHEN_PREFIX:-/kitchen}"

# Normalize: no trailing slash except root
KITCHEN_PREFIX="${KITCHEN_PREFIX%/}"

CONF="/etc/nginx/sites-available/triple-school-apps"
ENABLED="/etc/nginx/sites-enabled/triple-school-apps"

cat > "${CONF}" <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    client_max_body_size 25m;

    # --- SCIS learner release (Shalom pickup) ---
    location ^~ /admin/ {
        proxy_pass http://127.0.0.1:${SCIS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ^~ /teacher/ {
        proxy_pass http://127.0.0.1:${SCIS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ^~ /uploads/pickers/ {
        proxy_pass http://127.0.0.1:${SCIS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~ ^/api/(teachers|children|attendance|protected)(/|\$) {
        proxy_pass http://127.0.0.1:${SCIS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # --- Kitchen system (own URL prefix — does not touch SCIS or Ocean paths) ---
    location ^~ ${KITCHEN_PREFIX}/ {
        proxy_pass http://127.0.0.1:${KITCHEN_PORT}${KITCHEN_PREFIX}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # --- Ocean of Knowledge (default site) ---
    location / {
        proxy_pass http://127.0.0.1:${OCEAN_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

ln -sf "${CONF}" "${ENABLED}"
rm -f /etc/nginx/sites-enabled/default \
  /etc/nginx/sites-enabled/scis \
  /etc/nginx/sites-enabled/ocean-school \
  /etc/nginx/sites-enabled/dual-school-apps 2>/dev/null || true

nginx -t
systemctl reload nginx

echo ""
echo "Triple routing active."
echo "  SCIS:    http://YOUR_IP/admin/login.html  (port ${SCIS_PORT})"
echo "  Ocean:   http://YOUR_IP/  and /admin.html (port ${OCEAN_PORT})"
echo "  Kitchen: http://YOUR_IP${KITCHEN_PREFIX}/  (port ${KITCHEN_PORT})"
echo ""
echo "Before kitchen goes live: pm2 start ... with PORT=${KITCHEN_PORT} and app mounted at ${KITCHEN_PREFIX}/"
