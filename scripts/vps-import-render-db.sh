#!/usr/bin/env bash
# Restore a Render pg_dump into local VPS Postgres (scis_db).
# Run on VPS as root.
#
# Prerequisite: copy dump to VPS, e.g. /tmp/render.dump
#
# Usage:
#   bash scripts/vps-import-render-db.sh /tmp/render.dump
#
# Re-import existing dump without re-dumping Render:
#   SKIP_BACKUP=1 bash scripts/vps-import-render-db.sh /tmp/render.dump
#
# Optional env:
#   DB=scis_db  OWNER=scis_app  SKIP_BACKUP=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pg-pgdg-client.sh
source "${SCRIPT_DIR}/pg-pgdg-client.sh"

DUMP="${1:-}"
DB="${DB:-scis_db}"
OWNER="${OWNER:-scis_app}"

if [[ -z "${DUMP}" || ! -f "${DUMP}" ]]; then
  echo "Usage: bash scripts/vps-import-render-db.sh /tmp/render.dump"
  exit 1
fi

PG_RESTORE_BIN="$(resolve_pg_tool pg_restore)"
echo "Using ${PG_RESTORE_BIN} ($("${PG_RESTORE_BIN}" --version))"

if [[ "${SKIP_BACKUP:-}" != "1" ]]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP="/tmp/vps-${DB}-before-render-${STAMP}.dump"
  echo "Backing up current ${DB} to ${BACKUP} ..."
  sudo -u postgres pg_dump -Fc -f "${BACKUP}" "${DB}"
  echo "VPS backup saved: ${BACKUP}"
fi

echo "Stopping scis ..."
systemctl stop scis || true

echo "Restoring Render dump into ${DB} (this replaces existing rows) ..."
set +e
sudo -u postgres "${PG_RESTORE_BIN}" \
  --dbname="${DB}" \
  --clean \
  --if-exists \
  --no-owner \
  --role="${OWNER}" \
  --verbose \
  "${DUMP}" 2>&1 | tee /tmp/pg_restore-last.log | tail -40
RESTORE_EXIT=${PIPESTATUS[0]}
set -e

if [[ "${RESTORE_EXIT}" -ne 0 ]]; then
  echo "pg_restore exited with code ${RESTORE_EXIT} (see /tmp/pg_restore-last.log)" >&2
  if grep -qi 'FATAL\|unsupported version' /tmp/pg_restore-last.log; then
    exit "${RESTORE_EXIT}"
  fi
fi

echo "Fixing ownership and sequences ..."
sudo -u postgres psql -d "${DB}" <<SQL
ALTER TABLE IF EXISTS teachers OWNER TO ${OWNER};
ALTER TABLE IF EXISTS children OWNER TO ${OWNER};
ALTER TABLE IF EXISTS attendance_logs OWNER TO ${OWNER};
ALTER TABLE IF EXISTS authorized_pickers OWNER TO ${OWNER};

ALTER SEQUENCE IF EXISTS teachers_id_seq OWNER TO ${OWNER};
ALTER SEQUENCE IF EXISTS children_id_seq OWNER TO ${OWNER};
ALTER SEQUENCE IF EXISTS attendance_logs_id_seq OWNER TO ${OWNER};
ALTER SEQUENCE IF EXISTS authorized_pickers_id_seq OWNER TO ${OWNER};

GRANT USAGE ON SCHEMA public TO ${OWNER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${OWNER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${OWNER};

SELECT setval(pg_get_serial_sequence('children', 'id'), COALESCE((SELECT MAX(id) FROM children), 1));
SELECT setval(pg_get_serial_sequence('authorized_pickers', 'id'), COALESCE((SELECT MAX(id) FROM authorized_pickers), 1));
SELECT setval(pg_get_serial_sequence('attendance_logs', 'id'), COALESCE((SELECT MAX(id) FROM attendance_logs), 1));
SELECT setval(pg_get_serial_sequence('teachers', 'id'), COALESCE((SELECT MAX(id) FROM teachers), 1));
SQL

if [[ -d /var/www/scis/app/backend ]]; then
  echo "Running npm run migrate ..."
  (cd /var/www/scis/app/backend && npm run migrate)
fi

echo "Starting scis ..."
systemctl start scis
sleep 2
systemctl is-active scis || journalctl -u scis -n 20 --no-pager

echo ""
echo "Row counts:"
sudo -u postgres psql -d "${DB}" -c "SELECT 'children' AS t, COUNT(*) FROM children UNION ALL SELECT 'authorized_pickers', COUNT(*) FROM authorized_pickers UNION ALL SELECT 'attendance_logs', COUNT(*) FROM attendance_logs UNION ALL SELECT 'teachers', COUNT(*) FROM teachers;"

CHILDREN_COUNT="$(sudo -u postgres psql -d "${DB}" -tAc "SELECT COUNT(*) FROM children;")"
if [[ "${CHILDREN_COUNT}" -eq 0 ]]; then
  echo "WARNING: no children imported — check pg_restore output above." >&2
  exit 1
fi

echo ""
echo "Import complete. Test a photo URL from admin (e.g. /uploads/pickers/1_0.jpg)."
