#!/bin/bash
# Respaldo de la base (pg_dump) hacia S3 emulado. Uso: scripts/backup.sh [prod]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:-prod}"
AWS="$ROOT/scripts/aws-floci.sh"

# Host y puerto salen de terraform output (sin contrasena).
cd "$ROOT"
ADDR=$(scripts/tf.sh "$ENV" output -raw db_address)
PORT=$(scripts/tf.sh "$ENV" output -raw db_port)
BUCKET=$(scripts/tf.sh "$ENV" output -raw backup_bucket)
SECRET_ARN=$(scripts/tf.sh "$ENV" output -raw db_secret_arn)

if [ -z "$BUCKET" ]; then
  echo "Este ambiente no tiene bucket de backups." >&2
  exit 1
fi

PASS=$("$AWS" secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILE="/tmp/traccar-${ENV}-${STAMP}.sql"
export PGPASSWORD="$PASS"
"$ROOT/scripts/pg-client.sh" pg_dump -h "$ADDR" -p "$PORT" -U traccar -d traccar --no-owner --no-acl -f "$FILE"
unset PGPASSWORD
PASS=""

"$AWS" s3 cp "$FILE" "s3://${BUCKET}/${ENV}-db/${STAMP}.sql"
rm -f "$FILE" || true
echo "Respaldo subido a s3://${BUCKET}/${ENV}-db/${STAMP}.sql"
echo "$STAMP"
