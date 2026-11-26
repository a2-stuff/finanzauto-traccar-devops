#!/bin/bash
# Envoltorio de AWS CLI contra Floci. No imprime secretos.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi
export AWS_PROFILE="${AWS_PROFILE:-floci}"
export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_PAGER=""
exec aws --endpoint-url "$AWS_ENDPOINT_URL" "$@"
