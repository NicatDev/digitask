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

# Tətbiqin (gunicorn) işlədiyi istifadəçi və Python — paketlər məhz onun görəcəyi yerə qurulmalıdır.
SERVICE_USER="$(systemctl show -p User --value digitask.service 2>/dev/null || true)"
SERVICE_USER="${SERVICE_USER:-root}"

VENV=""
for d in "$BACKEND_DIR/venv" "$BACKEND_DIR/.venv" "$BACKEND_DIR/env" "$APP_DIR/venv" "$APP_DIR/.venv" "$APP_DIR/env"; do
    if [ -x "$d/bin/python" ]; then VENV="$d"; break; fi
done

PIP_AS=()
PIP_USER_FLAG=()
if [ -n "$VENV" ]; then
    PY="$VENV/bin/python"
    log "Backend: virtualenv $VENV"
else
    PY="$(command -v python3)"
    if [ "$SERVICE_USER" != "root" ]; then
        # Tətbiq istifadəçisinin paketləri (~/.local) — root kimi işlədilən manage.py də onları görsün
        SERVICE_HOME="$(getent passwd "$SERVICE_USER" | cut -d: -f6)"
        export PYTHONUSERBASE="$SERVICE_HOME/.local"
        PIP_AS=(sudo -u "$SERVICE_USER" -H)
        PIP_USER_FLAG=(--user)
    fi
    log "Backend: python $PY (xidmət istifadəçisi: $SERVICE_USER)"
fi

# Yalnız ÇATIŞMAYAN paketlər qurulur. Mövcud paketlər (məs. Django) heç vaxt avtomatik yenilənmir.
log "Backend: çatışmayan paketlər"
MISSING="$("${PIP_AS[@]}" "$PY" - requirements.txt <<'PYEOF'
import re, sys
from importlib import metadata
missing = []
for line in open(sys.argv[1], encoding="utf-8"):
    req = line.split("#", 1)[0].strip()
    if not req:
        continue
    name = re.split(r"[<>=!~\[; ]", req, maxsplit=1)[0]
    try:
        metadata.version(name)
    except metadata.PackageNotFoundError:
        missing.append(req)
print(" ".join(missing))
PYEOF
)"
if [ -n "$MISSING" ]; then
    echo "Quraşdırılır: $MISSING"
    # shellcheck disable=SC2086
    "${PIP_AS[@]}" "$PY" -m pip install "${PIP_USER_FLAG[@]}" $MISSING
else
    echo "Hamısı quraşdırılıb."
fi
"$PY" -c "import openpyxl, django; print('openpyxl', openpyxl.__version__, '| django', django.get_version())"

# Migration faylları git-də saxlanılmır (.gitignore) — serverdə yaradılır
log "Backend: makemigrations"
"$PY" manage.py makemigrations --noinput

log "Backend: migrate"
"$PY" manage.py migrate --noinput

log "Backend: collectstatic"
"$PY" manage.py collectstatic --noinput

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
