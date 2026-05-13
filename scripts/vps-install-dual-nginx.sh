# Run both apps on one VPS (same IP, port 80).
#
# SCIS pickup  -> 127.0.0.1:4000  (/admin/, /teacher/, /uploads/pickers/, SCIS /api/...)
# Ocean school -> 127.0.0.1:3001  (PM2 ocean-school — everything else)
#
# On VPS:
#   export OCEAN_PORT=3001
#   bash scripts/vps-install-dual-nginx.sh

set -euo pipefail

SCIS_PORT="${SCIS_PORT:-4000}"
OCEAN_PORT="${OCEAN_PORT:-3001}"

echo "SCIS port: ${SCIS_PORT}"
echo "Ocean port: ${OCEAN_PORT}"

CONF="/etc/nginx/sites-available/dual-school-apps"
ENABLED="/etc/nginx/sites-enabled/dual-school-apps"

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

    # --- Ocean of Knowledge (default) ---
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
  /etc/nginx/sites-enabled/ocean-school 2>/dev/null || true

nginx -t
systemctl reload nginx

echo ""
echo "Done. Test:"
echo "  Ocean home:  curl -sI http://127.0.0.1/ | head -1"
echo "  Ocean admin: curl -sI http://127.0.0.1/admin.html | head -1"
echo "  SCIS login:  curl -sI http://127.0.0.1/admin/login.html | head -1"
