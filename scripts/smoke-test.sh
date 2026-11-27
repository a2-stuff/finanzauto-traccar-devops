#!/bin/bash
# Prueba de humo: GET /api/server debe responder 200.
# Uso: scripts/smoke-test.sh [URL]
# Reintenta unos minutos: tras un apply, Traccar tarda en crear el esquema.
set -euo pipefail
URL="${1:-${TRACCAR_WEB_URL:-http://127.0.0.1:8082}}"
URL="${URL%/}"
echo "Probando ${URL}/api/server ..."
BODY=""
ok=0
t0=$(date +%s)
for i in $(seq 1 36); do
  if BODY=$(curl -sfS --max-time 20 "${URL}/api/server" 2>/dev/null); then
    if echo "$BODY" | jq -e '.version' >/dev/null; then
      ok=1
      break
    fi
  fi
  elapsed=$(( $(date +%s) - t0 ))
  echo "  esperando respuesta de /api/server ... ${elapsed}s (intento ${i}/36)"
  sleep 5
done
if [ "$ok" -ne 1 ]; then
  echo "Fallo: ${URL}/api/server no respondio 200 con version." >&2
  exit 1
fi
echo "OK: $(echo "$BODY" | jq -c '{version,id}')"
