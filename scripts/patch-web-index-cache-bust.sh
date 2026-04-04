#!/usr/bin/env bash
# Fuerza que navegadores y CDN descarguen de nuevo bootstrap + bundle principal.
#
# 1) index.html: flutter_bootstrap.js?v=<ts>
# 2) flutter_bootstrap.js: todas las referencias a main.dart.js pasan a main.dart.js?v=<ts>
# 3) deploy-stamp.txt: texto legible para comprobar en https://dominio/deploy-stamp.txt
#
# Uso: bash scripts/patch-web-index-cache-bust.sh [ruta/build/web]
set -euo pipefail

WEB_DIR="${1:-build/web}"
INDEX="${WEB_DIR}/index.html"
BOOT="${WEB_DIR}/flutter_bootstrap.js"
STAMP="${WEB_DIR}/deploy-stamp.txt"

if [[ ! -f "$INDEX" ]]; then
  echo "No existe $INDEX" >&2
  exit 1
fi

if [[ ! -f "$BOOT" ]]; then
  echo "No existe $BOOT" >&2
  exit 1
fi

TS="$(date +%s)"
ISO="$(date -Iseconds 2>/dev/null || date)"

# index.html: reemplaza cualquier src previo (con o sin ?v=)
sed -i.bak \
  "s|src=\"flutter_bootstrap\\.js[^\"]*\"|src=\"flutter_bootstrap.js?v=${TS}\"|" \
  "$INDEX"
rm -f "${INDEX}.bak"

# flutter_bootstrap.js: main.dart.js aparece pocas veces; añadir mismo ?v= al bundle
sed -i.bak "s/main\\.dart\\.js/main.dart.js?v=${TS}/g" "$BOOT"
rm -f "${BOOT}.bak"

{
  echo "deploy_iso=${ISO}"
  echo "cache_bust=${TS}"
} >"$STAMP"

echo "OK: cache_bust=${TS}"
echo "    ${STAMP} creado/actualizado"
