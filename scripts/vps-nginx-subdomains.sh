#!/usr/bin/env bash
# Nginx: one subdomain per app (recommended — no path clashes).
#
# DNS first (at your domain registrar), all A records -> VPS IP:
#   pickup.example.com
#   ocean.example.com
#   kitchen.example.com
#   gate.example.com
#
# Usage:
#   export BASE_DOMAIN=yourdomain.com
#   export PICKUP_HOST=pickup.yourdomain.com
#   export OCEAN_HOST=ocean.yourdomain.com
#   export KITCHEN_HOST=kitchen.yourdomain.com
#   export GATE_HOST=gate.yourdomain.com
#   bash scripts/vps-nginx-subdomains.sh
#
# SSL (after DNS propagates):
#   apt install -y certbot python3-certbot-nginx
#   certbot --nginx -d pickup... -d ocean... -d kitchen... -d gate...

set -euo pipefail

BASE_DOMAIN="${BASE_DOMAIN:-}"
PICKUP_HOST="${PICKUP_HOST:-pickup.${BASE_DOMAIN}}"
OCEAN_HOST="${OCEAN_HOST:-ocean.${BASE_DOMAIN}}"
KITCHEN_HOST="${KITCHEN_HOST:-kitchen.${BASE_DOMAIN}}"
GATE_HOST="${GATE_HOST:-gate.${BASE_DOMAIN}}"

SCIS_PORT="${SCIS_PORT:-4000}"
OCEAN_PORT="${OCEAN_PORT:-3001}"
KITCHEN_PORT="${KITCHEN_PORT:-3002}"
GATE_PORT="${GATE_PORT:-3003}"
GATE_STATIC="${GATE_STATIC:-/var/www/scis-gate/frontend/dist}"

if [[ -z "${BASE_DOMAIN}" ]]; then
  echo "Set BASE_DOMAIN, e.g. export BASE_DOMAIN=school.example.com"
  exit 1
fi

CONF="/etc/nginx/sites-available/school-subdomains"
ENABLED="/etc/nginx/sites-enabled/school-subdomains"

cat > "${CONF}" <<NGINX
# SCIS pickup
server {
    listen 80;
    listen [::]:80;
    server_name ${PICKUP_HOST};

    client_max_body_size 25m;

    location / {
        proxy_pass http://127.0.0.1:${SCIS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Ocean school
server {
    listen 80;
    listen [::]:80;
    server_name ${OCEAN_HOST};

    client_max_body_size 25m;

    location / {
        proxy_pass http://127.0.0.1:${OCEAN_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Kitchen
server {
    listen 80;
    listen [::]:80;
    server_name ${KITCHEN_HOST};

    client_max_body_size 25m;

    location / {
        proxy_pass http://127.0.0.1:${KITCHEN_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Gate: API -> Node; static UI from dist/ (if folder exists)
server {
    listen 80;
    listen [::]:80;
    server_name ${GATE_HOST};

    client_max_body_size 25m;

    location /api/ {
        proxy_pass http://127.0.0.1:${GATE_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        root ${GATE_STATIC};
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX

ln -sf "${CONF}" "${ENABLED}"
rm -f /etc/nginx/sites-enabled/default \
  /etc/nginx/sites-enabled/scis \
  /etc/nginx/sites-enabled/ocean-school \
  /etc/nginx/sites-enabled/dual-school-apps \
  /etc/nginx/sites-enabled/triple-school-apps 2>/dev/null || true

nginx -t
systemctl reload nginx

echo ""
echo "Subdomain nginx ready (HTTP). After DNS works, run certbot for HTTPS."
echo "  SCIS:    http://${PICKUP_HOST}/admin/login.html"
echo "  Ocean:   http://${OCEAN_HOST}/"
echo "  Kitchen: http://${KITCHEN_HOST}/"
echo "  Gate:    http://${GATE_HOST}/"
