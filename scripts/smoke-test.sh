#!/bin/bash
# Prueba de humo: GET /api/server debe responder 200.
# Uso: scripts/smoke-test.sh [URL]
set -euo pipefail
URL="${1:-${TRACCAR_WEB_URL:-http://127.0.0.1:8082}}"
URL="${URL%/}"
echo "Probando ${URL}/api/server ..."
BODY=$(curl -sfS --max-time 20 "${URL}/api/server")
echo "$BODY" | jq -e '.version' >/dev/null
echo "OK: $(echo "$BODY" | jq -c '{version,id}')"
