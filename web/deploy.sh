#!/usr/bin/env bash
# Publica la web y las descargas en el servidor. Antes: ./tools/export.sh
# El destino se lee de web/.deploy.env (no se sube al repositorio), con dos líneas:
#   HOST=mi-servidor
#   DIR=/ruta/en/el/servidor
# El puerto y la subred van en un archivo .env en esa carpeta del servidor (HALCON_PORT, HALCON_SUBNET).
# Uso: ./web/deploy.sh
set -euo pipefail
cd "$(dirname "$0")"
[ -f .deploy.env ] || { echo "❌ falta web/.deploy.env con HOST y DIR"; exit 1; }
# shellcheck disable=SC1091
source ./.deploy.env
: "${HOST:?falta HOST en web/.deploy.env}" "${DIR:?falta DIR en web/.deploy.env}"
[ -f ../build/manifest.json ] || { echo "❌ falta build/manifest.json: ejecuta ./tools/export.sh"; exit 1; }
ssh "$HOST" "mkdir -p '$DIR'"
find site/downloads -type f ! -name .gitkeep -delete
cp ../build/manifest.json ../build/*.tar.gz ../build/*.zip site/downloads/
rsync -az --delete --exclude .env --exclude .deploy.env ./ "$HOST:$DIR/"
ssh "$HOST" "cd '$DIR' && docker compose up -d && docker compose restart counter web && docker compose ps"
