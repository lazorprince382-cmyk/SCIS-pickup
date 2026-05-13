#!/usr/bin/env bash
# Dump Render Postgres for migration to VPS.
#
# Set URL one of these ways:
#   export RENDER_DATABASE_URL='postgresql://...'
#   echo 'postgresql://...' > scripts/render-database.url   # gitignored, VPS only
#
# On VPS (all-in-one dump + import):
#   bash scripts/vps-pull-and-import-render-db.sh
#
# On PC only (dump then scp):
#   bash scripts/render-export-db.sh
#   scp backups/render-*.dump root@185.214.134.41:/tmp/render.dump

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pg-pgdg-client.sh
source "${SCRIPT_DIR}/pg-pgdg-client.sh"

URL_FILE="${ROOT}/scripts/render-database.url"

if [[ -z "${RENDER_DATABASE_URL:-}" && -f "${URL_FILE}" ]]; then
  RENDER_DATABASE_URL="$(tr -d '\r\n' < "${URL_FILE}")"
  export RENDER_DATABASE_URL
fi

if [[ -z "${RENDER_DATABASE_URL:-}" ]]; then
  echo "Set RENDER_DATABASE_URL or create scripts/render-database.url (see render-database.url.example)."
  exit 1
fi

OUT_DIR="${ROOT}/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT:-${OUT_DIR}/render-${STAMP}.dump}"

mkdir -p "$(dirname "${OUT}")"

PG_DUMP_BIN="$(resolve_pg_tool pg_dump)"
echo "Using ${PG_DUMP_BIN} ($("${PG_DUMP_BIN}" --version))"

echo "Dumping Render database to ${OUT} ..."
"${PG_DUMP_BIN}" "${RENDER_DATABASE_URL}" \
  --format=custom \
  --no-owner \
  --no-acl \
  --verbose \
  --file="${OUT}"

echo "Done. Size: $(du -h "${OUT}" | cut -f1)"
if [[ "${OUT}" != /tmp/render.dump ]]; then
  echo "Copy to VPS: scp \"${OUT}\" root@185.214.134.41:/tmp/render.dump"
fi
