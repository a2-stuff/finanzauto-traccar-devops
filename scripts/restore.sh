#!/bin/bash
# Restaura un respaldo de S3 en otra base (por defecto, una DB temporal).
# Uso: scripts/restore.sh [prod] [s3://bucket/key]
# Nunca pisa la base traccar de Prod: siempre usa traccar_restore.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:-prod}"
S3URI="${2:-}"
AWS="$ROOT/scripts/aws-floci.sh"
# shellcheck source=progress.sh
. "$ROOT/scripts/progress.sh"

progress_start 5

progress_step "Leyendo datos del ambiente ${ENV}"
OUTS=$("$ROOT/scripts/tf.sh" "$ENV" output -json)
ADDR=$(echo "$OUTS" | jq -r '.db_address.value')
PORT=$(echo "$OUTS" | jq -r '.db_port.value')
BUCKET=$(echo "$OUTS" | jq -r '.backup_bucket.value')
SECRET_ARN=$(echo "$OUTS" | jq -r '.db_secret_arn.value')
progress_ok

progress_step "Localizando el respaldo en S3"
if [ -z "$S3URI" ]; then
  KEY=$("$AWS" s3 ls "s3://${BUCKET}/${ENV}-db/" | awk '{print $4}' | sort | tail -n 1)
  if [ -z "$KEY" ]; then
    progress_fail
    echo "No hay respaldos en s3://${BUCKET}/${ENV}-db/" >&2
    exit 1
  fi
  S3URI="s3://${BUCKET}/${ENV}-db/${KEY}"
fi
progress_ok "$S3URI"

progress_step "Descargando el respaldo"
FILE=/tmp/traccar-restore.sql
"$AWS" s3 cp "$S3URI" "$FILE" --only-show-errors
progress_ok

progress_step "Restaurando en la base traccar_restore (no se pisa Prod)"
PASS=$("$AWS" secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)
export PGPASSWORD="$PASS"
PG="$ROOT/scripts/pg-client.sh"
"$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d postgres -v ON_ERROR_STOP=1 \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'traccar_restore';" \
  -c "DROP DATABASE IF EXISTS traccar_restore;" \
  -c "CREATE DATABASE traccar_restore OWNER traccar;" >/dev/null
if [[ "$S3URI" == *.gz ]] || gzip -t "$FILE" 2>/dev/null; then
  gzip -dc "$FILE" | "$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d traccar_restore -v ON_ERROR_STOP=1 >/tmp/traccar-restore.log
else
  "$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d traccar_restore -v ON_ERROR_STOP=1 -f "$FILE" >/tmp/traccar-restore.log
fi
progress_ok

progress_step "Verificando tablas y conteos"
COUNT=$("$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d traccar_restore -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
DEVICES=$("$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d traccar_restore -Atc "SELECT count(*) FROM tc_devices;" 2>/dev/null || echo 0)
POSITIONS=$("$PG" psql -h "$ADDR" -p "$PORT" -U traccar -d traccar_restore -Atc "SELECT count(*) FROM tc_positions;" 2>/dev/null || echo 0)
unset PGPASSWORD
PASS=""
rm -f "$FILE" 2>/dev/null || true
if [ "${COUNT}" = "0" ]; then
  progress_fail
  echo "Fallo de verificacion: la base restaurada no tiene tablas." >&2
  exit 1
fi
progress_ok "tablas ${COUNT}, dispositivos ${DEVICES}, posiciones ${POSITIONS}"

echo "Restauracion OK en la base traccar_restore. Tablas publicas: ${COUNT}. Dispositivos: ${DEVICES}. Posiciones: ${POSITIONS}."
progress_total
