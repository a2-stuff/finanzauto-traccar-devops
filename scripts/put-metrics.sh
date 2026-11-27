#!/bin/bash
# Publica metricas custom de disponibilidad y CPU a CloudWatch (Floci).
# Uso: scripts/put-metrics.sh <dev|uat|prod> <0|1>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:?ambiente}"
AVAIL="${2:?0 o 1}"
AWS="$ROOT/scripts/aws-floci.sh"
CPU="${3:-5}"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
"$AWS" cloudwatch put-metric-data \
  --namespace AVL/Traccar \
  --metric-data "[
    {\"MetricName\":\"Availability\",\"Dimensions\":[{\"Name\":\"Environment\",\"Value\":\"${ENV}\"}],\"Timestamp\":\"${TS}\",\"Value\":${AVAIL},\"Unit\":\"None\"},
    {\"MetricName\":\"CpuPercent\",\"Dimensions\":[{\"Name\":\"Environment\",\"Value\":\"${ENV}\"}],\"Timestamp\":\"${TS}\",\"Value\":${CPU},\"Unit\":\"Percent\"}
  ]"
echo "Metrica Availability=${AVAIL} CpuPercent=${CPU} publicada para ${ENV}."
