#!/bin/bash
# Ejecuta un cliente de PostgreSQL. Usa psql/pg_dump del host si existen;
# si no, usa la imagen postgres:16 en la red del host.
set -euo pipefail
CMD="${1:?comando psql o pg_dump}"
shift
if command -v "$CMD" >/dev/null 2>&1; then
  exec "$CMD" "$@"
fi
if ! docker image inspect postgres:16 >/dev/null 2>&1; then
  docker pull postgres:16 >/dev/null
fi
# Montamos /tmp para archivos de dump. --network host llega a Floci RDS.
exec docker run --rm --network host \
  -e PGPASSWORD \
  -v /tmp:/tmp \
  postgres:16 "$CMD" "$@"
