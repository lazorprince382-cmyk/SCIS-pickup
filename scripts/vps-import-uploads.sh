#!/usr/bin/env bash
# Extract picker photos into VPS UPLOADS_DIR (default /var/www/scis/uploads/pickers).
# Run on VPS as root.
#
# Usage:
#   bash scripts/vps-import-uploads.sh /tmp/scis-picker-uploads.tar.gz

set -euo pipefail

ARCHIVE="${1:-}"
DEST="${UPLOADS_DIR:-/var/www/scis/uploads/pickers}"

if [[ -z "${ARCHIVE}" || ! -f "${ARCHIVE}" ]]; then
  echo "Usage: bash scripts/vps-import-uploads.sh /path/to/scis-picker-uploads.tar.gz"
  exit 1
fi

mkdir -p "${DEST}"
echo "Extracting ${ARCHIVE} -> ${DEST}"
tar -xzf "${ARCHIVE}" -C "${DEST}"

# Node (scis.service) must be able to read/write new files
chown -R root:root "${DEST}" 2>/dev/null || true
chmod -R u+rwX,g+rX "${DEST}"

COUNT="$(find "${DEST}" -type f | wc -l)"
echo "Done. ${COUNT} files under ${DEST}"
echo "Sample:"
ls -la "${DEST}" | head -15

if ! grep -q "UPLOADS_DIR=${DEST}" /var/www/scis/app/backend/.env 2>/dev/null; then
  echo ""
  echo "Ensure backend .env contains:"
  echo "  UPLOADS_DIR=${DEST}"
fi
