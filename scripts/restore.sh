#!/bin/bash
# Restaura un respaldo de S3 en otra base (por defecto, una DB temporal).
# Uso: scripts/restore.sh [prod] [s3://bucket/key]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:-prod}"
S3URI="${2:-}"
AWS="$ROOT/scripts/aws-floci.sh"

ADDR=$( "$ROOT/scripts/tf.sh" "$ENV" output -raw db_address )
PORT=$( "$ROOT/scripts/tf.sh" "$ENV" output -raw db_port )
BUCKET=$( "$ROOT/scripts/tf.sh" "$ENV" output -raw backup_bucket )
SECRET_ARN=$( "$ROOT/scripts/tf.sh" "$ENV" output -raw db_secret_arn )
PASS=$("$AWS" secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)

if [ -z "$S3URI" ]; then
  KEY=$("$AWS" s3 ls "s3://${BUCKET}/prod-db/" | awk '{print $4}' | sort | tail -n 1)
  if [ -z "$KEY" ]; then
    echo "No hay respaldos en s3://${BUCKET}/prod-db/" >&2
    exit 1
  fi
  S3URI="s3://${BUCKET}/prod-db/${KEY}"
fi

FILE=/tmp/traccar-restore.sql
"$AWS" s3 cp "$S3URI" "$FILE"
export PGPASSWORD="$PASS"
PG="$ROOT/scripts/pg-client.sh"
# Restaura en una base aparte para no pisar prod a ciegas.
"$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d postgres -v ON_ERROR_STOP=1 \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'traccar_restore';" \
  -c "DROP DATABASE IF EXISTS traccar_restore;" \
  -c "CREATE DATABASE traccar_restore OWNER traccar;"
"$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d traccar_restore -v ON_ERROR_STOP=1 -f "$FILE" >/tmp/traccar-restore.log
COUNT=$("$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d traccar_restore -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
unset PGPASSWORD
PASS=""
rm -f "$FILE"
echo "Restauracion OK en la base traccar_restore. Tablas publicas: ${COUNT}."
