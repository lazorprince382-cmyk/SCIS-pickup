#!/usr/bin/env bash
# Dump Render Postgres for migration to VPS.
# Run from your PC or the VPS (anywhere with pg_dump and network to Render).
#
# 1. Render Dashboard → Postgres (scis-db) → Connect → copy **External** Database URL
# 2. export RENDER_DATABASE_URL='postgresql://user:pass@host/dbname'
# 3. bash scripts/render-export-db.sh
#
# Output: ./backups/render-YYYYMMDD-HHMMSS.dump

set -euo pipefail

if [[ -z "${RENDER_DATABASE_URL:-}" ]]; then
  echo "Set RENDER_DATABASE_URL to the Render **External** Database URL first."
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT}/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT_DIR}/render-${STAMP}.dump"

mkdir -p "${OUT_DIR}"

echo "Dumping Render database to ${OUT} ..."
pg_dump "${RENDER_DATABASE_URL}" \
  --format=custom \
  --no-owner \
  --no-acl \
  --verbose \
  --file="${OUT}"

echo "Done. Size: $(du -h "${OUT}" | cut -f1)"
echo "Copy to VPS: scp \"${OUT}\" root@185.214.134.41:/tmp/render.dump"
