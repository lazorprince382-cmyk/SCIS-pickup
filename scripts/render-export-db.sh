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

install_pgdg_client() {
  local ver="$1"
  if [[ -x "/usr/lib/postgresql/${ver}/bin/pg_dump" ]]; then
    return 0
  fi
  echo "Installing PostgreSQL ${ver} client (Render uses PG ${ver}) ..."
  apt-get update -y
  apt-get install -y curl ca-certificates gnupg lsb-release
  install -d /usr/share/postgresql-common/pgdg
  curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc
  sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
  apt-get update -y
  apt-get install -y "postgresql-client-${ver}"
}

resolve_pg_dump() {
  local required="${PG_CLIENT_VERSION:-18}"
  if [[ -x "/usr/lib/postgresql/${required}/bin/pg_dump" ]]; then
    echo "/usr/lib/postgresql/${required}/bin/pg_dump"
    return
  fi
  if command -v "pg_dump${required}" >/dev/null 2>&1; then
    echo "pg_dump${required}"
    return
  fi
  if command -v pg_dump >/dev/null 2>&1; then
    local dump_ver
    dump_ver="$(pg_dump --version | awk '{print $3}' | cut -d. -f1)"
    if [[ "${dump_ver}" -ge "${required}" ]]; then
      echo "pg_dump"
      return
    fi
  fi
  install_pgdg_client "${required}"
  echo "/usr/lib/postgresql/${required}/bin/pg_dump"
}

PG_DUMP_BIN="$(resolve_pg_dump)"
echo "Using ${PG_DUMP_BIN} ($(${PG_DUMP_BIN} --version))"

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
