#!/usr/bin/env bash
# Render → VPS migration checklist (SCIS pickup)
# Run each section in order. Scripts live in this repo under scripts/
#
# -------- PART 1: Database --------
# 1. Render Dashboard → Postgres (scis-db) → copy **External** Database URL
# 2. On your PC (needs pg_dump):
#      export RENDER_DATABASE_URL='postgresql://...'
#      bash scripts/render-export-db.sh
#      scp backups/render-*.dump root@185.214.134.41:/tmp/render.dump
# 3. On VPS:
#      cd /var/www/scis/app && git pull
#      bash scripts/vps-import-render-db.sh /tmp/render.dump
#
# -------- PART 2: Picker photos (Render disk /mnt/scis-upload) --------
# 1. Render Dashboard → scis-pickup web service → Shell:
#      bash render-shell-pack-uploads.sh
#    (or: tar czf /tmp/scis-picker-uploads.tar.gz -C /mnt/scis-upload .)
# 2. Upload archive to VPS (transfer.sh example):
#      curl --upload-file /tmp/scis-picker-uploads.tar.gz https://transfer.sh/scis-picker-uploads.tar.gz
# 3. On VPS:
#      curl -L -o /tmp/scis-picker-uploads.tar.gz 'PASTE_URL_FROM_TRANSFER_SH'
#      bash /var/www/scis/app/scripts/vps-import-uploads.sh /tmp/scis-picker-uploads.tar.gz
#      grep UPLOADS_DIR /var/www/scis/app/backend/.env
#      systemctl restart scis
#
# -------- PART 3: Verify --------
#   curl -s http://127.0.0.1/health
#   sudo -u postgres psql -d scis_db -c "SELECT COUNT(*) FROM children;"
#   Open admin → All Children; check holder photos load (/uploads/pickers/{id}_{0-3}.jpg)

echo "See comments in scripts/migrate-render-to-vps.sh for the full steps."
echo "Helper scripts:"
ls -1 "$(dirname "$0")"/render-export-db.sh \
  "$(dirname "$0")"/render-shell-pack-uploads.sh \
  "$(dirname "$0")"/vps-import-render-db.sh \
  "$(dirname "$0")"/vps-import-uploads.sh 2>/dev/null || true
