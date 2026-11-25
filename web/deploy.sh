#!/usr/bin/env bash
# Publica la web y las descargas en el servidor. Antes: ./tools/export.sh
# Uso: ./web/deploy.sh [host] [carpeta]    (por defecto servidor /srv/operacion-halcon-web)
set -euo pipefail
HOST="${1:-servidor}"
DIR="${2:-/srv/operacion-halcon-web}"
cd "$(dirname "$0")"
[ -f ../build/manifest.json ] || { echo "❌ falta build/manifest.json: ejecuta ./tools/export.sh"; exit 1; }
cp ../build/manifest.json ../build/*.tar.gz ../build/*.zip site/downloads/
ssh "$HOST" "mkdir -p '$DIR'"
rsync -az --delete ./ "$HOST:$DIR/"
ssh "$HOST" "cd '$DIR' && docker compose up -d && docker compose restart web && docker compose ps"
