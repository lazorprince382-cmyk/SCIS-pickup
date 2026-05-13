#!/usr/bin/env bash
# Shared helpers: install/use PostgreSQL client tools from PGDG (e.g. v18 for Render).

install_pgdg_client() {
  local ver="$1"
  if [[ -x "/usr/lib/postgresql/${ver}/bin/pg_dump" ]]; then
    return 0
  fi
  if command -v "pg_dump${ver}" >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing PostgreSQL ${ver} client ..." >&2
  apt-get update -y >&2
  apt-get install -y curl ca-certificates gnupg lsb-release >&2
  install -d /usr/share/postgresql-common/pgdg
  curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc
  sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
  apt-get update -y >&2
  apt-get install -y "postgresql-client-${ver}" >&2
}

# resolve_pg_tool pg_dump|pg_restore [version]
resolve_pg_tool() {
  local tool="$1"
  local required="${2:-${PG_CLIENT_VERSION:-18}}"
  local bin=""

  if [[ -x "/usr/lib/postgresql/${required}/bin/${tool}" ]]; then
    bin="/usr/lib/postgresql/${required}/bin/${tool}"
  elif command -v "${tool}${required}" >/dev/null 2>&1; then
    bin="$(command -v "${tool}${required}")"
  elif command -v "${tool}" >/dev/null 2>&1; then
    local tool_ver
    tool_ver="$("${tool}" --version | awk '{print $3}' | cut -d. -f1)"
    if [[ "${tool_ver}" -ge "${required}" ]]; then
      bin="$(command -v "${tool}")"
    fi
  fi

  if [[ -z "${bin}" ]]; then
    install_pgdg_client "${required}"
    if [[ -x "/usr/lib/postgresql/${required}/bin/${tool}" ]]; then
      bin="/usr/lib/postgresql/${required}/bin/${tool}"
    elif command -v "${tool}${required}" >/dev/null 2>&1; then
      bin="$(command -v "${tool}${required}")"
    elif command -v "${tool}" >/dev/null 2>&1; then
      bin="$(command -v "${tool}")"
    fi
  fi

  if [[ -z "${bin}" ]]; then
    echo "Could not find ${tool} (PG ${required})." >&2
    exit 1
  fi
  printf '%s' "${bin}"
}
