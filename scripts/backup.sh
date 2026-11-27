#!/bin/bash
# Respaldo de la base (pg_dump) hacia S3 emulado. Uso: scripts/backup.sh [prod]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:-prod}"
AWS="$ROOT/scripts/aws-floci.sh"
# shellcheck source=progress.sh
. "$ROOT/scripts/progress.sh"

cd "$ROOT"
progress_start 4

progress_step "Leyendo datos del ambiente ${ENV}"
OUTS=$("$ROOT/scripts/tf.sh" "$ENV" output -json)
ADDR=$(echo "$OUTS" | jq -r '.db_address.value')
PORT=$(echo "$OUTS" | jq -r '.db_port.value')
BUCKET=$(echo "$OUTS" | jq -r '.backup_bucket.value')
SECRET_ARN=$(echo "$OUTS" | jq -r '.db_secret_arn.value')
if [ -z "$BUCKET" ] || [ "$BUCKET" = "null" ]; then
  progress_fail
  echo "Este ambiente no tiene bucket de backups." >&2
  exit 1
fi
progress_ok

progress_step "Exportando la base (pg_dump)"
PASS=$("$AWS" secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILE="/tmp/traccar-${ENV}-${STAMP}.sql"
export PGPASSWORD="$PASS"
"$ROOT/scripts/pg-client.sh" pg_dump -h "$ADDR" -p "$PORT" -U traccar -d traccar --no-owner --no-acl -f "$FILE"
unset PGPASSWORD
PASS=""
SIZE=$(wc -c < "$FILE" | tr -d ' ')
progress_ok "${SIZE} bytes"

progress_step "Subiendo el respaldo a S3"
"$AWS" s3 cp "$FILE" "s3://${BUCKET}/${ENV}-db/${STAMP}.sql" --only-show-errors
progress_ok "s3://${BUCKET}/${ENV}-db/${STAMP}.sql"

progress_step "Limpiando archivo temporal"
rm -f "$FILE" 2>/dev/null || true
progress_ok

echo "Respaldo subido a s3://${BUCKET}/${ENV}-db/${STAMP}.sql"
echo "$STAMP"
progress_total
