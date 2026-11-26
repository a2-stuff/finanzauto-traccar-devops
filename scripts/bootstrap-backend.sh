#!/bin/bash
# Crea el bucket de estado y la tabla de locks en Floci.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
AWS="$ROOT/scripts/aws-floci.sh"

echo "Creando bucket avl-tfstate (si no existe)..."
"$AWS" s3api create-bucket --bucket avl-tfstate --region us-east-1 >/dev/null 2>&1 || true
"$AWS" s3api head-bucket --bucket avl-tfstate

echo "Creando tabla DynamoDB avl-tflock (si no existe)..."
if ! "$AWS" dynamodb describe-table --table-name avl-tflock >/dev/null 2>&1; then
  "$AWS" dynamodb create-table \
    --table-name avl-tflock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null
fi
"$AWS" dynamodb wait table-exists --table-name avl-tflock
echo "Backend listo en Floci."
