#!/bin/bash
# Send OsmAnd positions to the local Traccar instance so a vehicle moves on the map.
# Stop with Ctrl+C.
set -euo pipefail
ID="${TRACCAR_DEVICE_ID:-demo-osmand}"
HOST="${TRACCAR_OSMAND_URL:-http://127.0.0.1:5055}"

# A short loop around the Centro Historico, Cartagena.
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

echo "Sending OsmAnd positions for device ${ID} to ${HOST}"
echo "Open http://localhost:8082 and watch the map. Ctrl+C to stop."
i=0
while true; do
  IFS=',' read -r lat lon bearing <<< "${POINTS[$((i % ${#POINTS[@]}))]}"
  ts=$(date +%s)
  if ! curl -sf --max-time 5 \
    "${HOST}/?id=${ID}&lat=${lat}&lon=${lon}&timestamp=${ts}&speed=15&bearing=${bearing}&hdop=1&altitude=5" \
    >/dev/null; then
    echo "Warning: OsmAnd POST failed (is Traccar up on port 5055?)" >&2
  fi
  i=$((i + 1))
  sleep 2
done
