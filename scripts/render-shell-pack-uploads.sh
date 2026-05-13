#!/usr/bin/env bash
# Run inside **Render Web Service Shell** (scis-pickup), not on the VPS.
#
# Persistent disk on Render was mounted at /mnt/scis-upload with UPLOADS_DIR=/mnt/scis-upload
#
# Usage (Render Shell):
#   bash render-shell-pack-uploads.sh
# Or paste the commands below manually.

set -euo pipefail

UPLOAD_SRC="${UPLOAD_SRC:-/mnt/scis-upload}"
ARCHIVE="/tmp/scis-picker-uploads.tar.gz"

if [[ ! -d "${UPLOAD_SRC}" ]]; then
  echo "Upload folder not found: ${UPLOAD_SRC}"
  echo "Try: ls /mnt/scis-upload /opt/render/project/data/uploads/pickers"
  exit 1
fi

echo "Files in ${UPLOAD_SRC}:"
ls -la "${UPLOAD_SRC}" | head -20
echo "..."
echo "Count: $(find "${UPLOAD_SRC}" -type f | wc -l) files"

tar -czf "${ARCHIVE}" -C "${UPLOAD_SRC}" .
ls -lh "${ARCHIVE}"

cat <<'EOF'

Next — send the archive to your VPS (pick one):

A) transfer.sh (quick, good for < ~500MB):
   curl --upload-file /tmp/scis-picker-uploads.tar.gz https://transfer.sh/scis-picker-uploads.tar.gz
   Copy the https URL it prints, then on the VPS:
   curl -L -o /tmp/scis-picker-uploads.tar.gz 'PASTE_URL_HERE'
   bash /var/www/scis/app/scripts/vps-import-uploads.sh /tmp/scis-picker-uploads.tar.gz

B) From your PC (if Render CLI / SSH is set up):
   render ssh scis-pickup -- "cat /tmp/scis-picker-uploads.tar.gz" > scis-picker-uploads.tar.gz
   scp scis-picker-uploads.tar.gz root@185.214.134.41:/tmp/
   ssh root@185.214.134.41 'bash /var/www/scis/app/scripts/vps-import-uploads.sh /tmp/scis-picker-uploads.tar.gz'

EOF
