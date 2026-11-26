#!/bin/bash
# Prueba controlada de la alarma de disponibilidad (O6).
# Publica Availability=0, espera el estado ALARM, y restaura Availability=1.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:-prod}"
AWS="$ROOT/scripts/aws-floci.sh"
ALARM="avl-${ENV}-traccar-availability"

echo "Publicando Availability=0 para disparar ${ALARM}..."
"$ROOT/scripts/put-metrics.sh" "$ENV" 0 90

echo "Esperando estado ALARM (hasta 90s)..."
ok=0
for i in $(seq 1 18); do
  STATE=$("$AWS" cloudwatch describe-alarms --alarm-names "$ALARM" \
    --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null || echo UNKNOWN)
  echo "  intento ${i}: ${STATE}"
  if [ "$STATE" = "ALARM" ]; then
    ok=1
    break
  fi
  sleep 5
done

echo "Restaurando Availability=1..."
"$ROOT/scripts/put-metrics.sh" "$ENV" 1 5

if [ "$ok" -ne 1 ]; then
  echo "No se observo estado ALARM. Revisa si CloudWatch de Floci evalua alarmas." >&2
  exit 1
fi
echo "Alarma disparada y restaurada."
