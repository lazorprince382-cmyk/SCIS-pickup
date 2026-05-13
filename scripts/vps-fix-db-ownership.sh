#!/usr/bin/env bash
# Run ON THE VPS as root (after schema.sql was applied as postgres).
# Fixes: scis_app cannot ALTER/INSERT because tables are owned by postgres.
#
# Usage:
#   bash scripts/vps-fix-db-ownership.sh
# Or from repo root on server:
#   bash scripts/vps-fix-db-ownership.sh
#
# Optional env overrides:
#   DB=scis_db OWNER=scis_app bash scripts/vps-fix-db-ownership.sh

set -euo pipefail

DB="${DB:-scis_db}"
OWNER="${OWNER:-scis_app}"

echo "Applying ownership to ${OWNER} in database ${DB} ..."

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
SQL

echo "Done. Next from backend folder: npm run migrate && node scripts/seed-teacher.js"
