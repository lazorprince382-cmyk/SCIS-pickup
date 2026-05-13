#!/usr/bin/env bash
# Run ON THE VPS: dump Render Postgres and import into local scis_db.
#
# Prerequisite: scripts/render-database.url exists (gitignored) OR RENDER_DATABASE_URL is set.
#
#   cd /var/www/scis/app
#   git pull
#   bash scripts/vps-pull-and-import-render-db.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUMP="/tmp/render.dump"

export OUT="${DUMP}"
bash "${ROOT}/scripts/render-export-db.sh"
bash "${ROOT}/scripts/vps-import-render-db.sh" "${DUMP}"
