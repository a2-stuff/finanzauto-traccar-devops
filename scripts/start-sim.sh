#!/bin/bash
# Envia posiciones OsmAnd a Traccar. Por defecto apunta al demo local.
# Para Prod en Floci: TRACCAR_OSMAND_URL=http://127.0.0.1:5055
# Para UAT: TRACCAR_OSMAND_URL=http://127.0.0.1:5155
# Para Dev: TRACCAR_OSMAND_URL=http://127.0.0.1:5255
# Detener con Ctrl+C.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi
ID="${TRACCAR_DEVICE_ID:-demo-osmand}"
HOST="${TRACCAR_OSMAND_URL:-http://127.0.0.1:5055}"

POINTS=(
  "10.4230,-75.5480,90"
  "10.4240,-75.5470,45"
  "10.4255,-75.5465,10"
  "10.4265,-75.5475,320"
  "10.4270,-75.5490,270"
  "10.4260,-75.5500,220"
  "10.4245,-75.5505,180"
  "10.4235,-75.5495,140"
)

echo "Enviando posiciones OsmAnd del dispositivo ${ID} a ${HOST}"
echo "Abre la UI de Traccar y observa el mapa. Ctrl+C para detener."
i=0
while true; do
  IFS=',' read -r lat lon bearing <<< "${POINTS[$((i % ${#POINTS[@]}))]}"
  ts=$(date +%s)
  if ! curl -sf --max-time 5 \
    "${HOST}/?id=${ID}&lat=${lat}&lon=${lon}&timestamp=${ts}&speed=15&bearing=${bearing}&hdop=1&altitude=5" \
    >/dev/null; then
    echo "Aviso: fallo el envio OsmAnd. Esta Traccar arriba en ese puerto?" >&2
  fi
  i=$((i + 1))
  sleep 2
done
