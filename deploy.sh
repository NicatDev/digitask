#!/usr/bin/env bash
# Digitask deploy: frontend build + backend update + restart services.
# Usage (on server):  sudo bash /app/deploy.sh
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$APP_DIR/frontend"
BACKEND_DIR="$APP_DIR/backend"

log() { echo -e "\n\033[1;32m==> $*\033[0m"; }

# --- Frontend -------------------------------------------------------------
log "Frontend: npm install"
cd "$FRONTEND_DIR"
npm install

log "Frontend: npm run build"
npm run build

# --- Backend --------------------------------------------------------------
cd "$BACKEND_DIR"

# Find the virtualenv (first match wins)
VENV=""
for d in "$BACKEND_DIR/venv" "$BACKEND_DIR/.venv" "$BACKEND_DIR/env" "$APP_DIR/venv" "$APP_DIR/.venv" "$APP_DIR/env"; do
    if [ -f "$d/bin/activate" ]; then VENV="$d"; break; fi
done

if [ -n "$VENV" ]; then
    log "Backend: using virtualenv $VENV"
    # shellcheck disable=SC1091
    source "$VENV/bin/activate"
else
    echo "WARNING: virtualenv not found, using system python" >&2
fi

log "Backend: pip install -r requirements.txt"
pip install -r requirements.txt

# Migration faylları git-də saxlanılmır (.gitignore) — serverdə yaradılır
log "Backend: makemigrations"
python manage.py makemigrations --noinput

log "Backend: migrate"
python manage.py migrate --noinput

log "Backend: collectstatic"
python manage.py collectstatic --noinput

# --- Restart services -----------------------------------------------------
log "Restarting services"
systemctl daemon-reload
systemctl restart redis
systemctl restart digitask.socket digitask.service
systemctl restart daphne

log "Nginx: config test + reload"
nginx -t
systemctl reload nginx

log "Service status"
for s in redis digitask daphne nginx; do
    printf "  %-10s %s\n" "$s" "$(systemctl is-active "$s")"
done

log "Deploy finished"
