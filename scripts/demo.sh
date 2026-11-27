#!/bin/bash
# Menu de demo para la grabacion. Uso: scripts/demo.sh [1-6|all]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

SIM_PIDFILE=/tmp/avl-demo-sim.pid
SIM_LOG=/tmp/avl-demo-sim.log
SIM_SECONDS=300

if ! command -v jq >/dev/null 2>&1; then
  echo "No se encontro jq, hace falta para las pruebas de humo y las salidas de Terraform." >&2
  echo "En Arch: sudo pacman -S --noconfirm jq" >&2
  exit 1
fi

menu() {
  cat <<'EOF'
Uso: scripts/demo.sh <1-6>
     scripts/demo.sh --all

  1  Prod en vivo y humo en los tres ambientes
  2  Simulador GPS (demo-osmand en http://127.0.0.1:8082, 5 min en segundo plano)
  3  Alarma de disponibilidad (CloudWatch en Floci)
  4  Respaldo a S3
  5  Rollback (objetivo: menos de 5 minutos)
  6  Restore en la base traccar_restore

  --all, -all o all  Corre los pasos 1 a 6 en orden y se detiene al primer fallo.

Sin argumento, o un valor invalido, se muestra este menu.
EOF
}

banner() {
  local n="$1" title="$2"
  echo
  echo "== Paso ${n}/6: ${title} =="
}

sim_running() {
  [ -f "$SIM_PIDFILE" ] && kill -0 "$(cat "$SIM_PIDFILE" 2>/dev/null)" 2>/dev/null
}

start_sim_background() {
  banner 2 "Simulador GPS"
  echo "Envia puntos cerca del Centro Historico de Cartagena al OsmAnd de Prod (puerto 5055)."
  echo "Abre http://127.0.0.1:8082 y haz clic en el dispositivo demo-osmand."
  if sim_running; then
    echo "El simulador ya esta corriendo (pid $(cat "$SIM_PIDFILE"))."
    echo "Se detiene solo a los 5 minutos, o antes con: kill \$(cat $SIM_PIDFILE)"
    echo "Log: $SIM_LOG"
    return 0
  fi
  rm -f "$SIM_PIDFILE" "$SIM_LOG"
  # timeout es el padre de start-sim.sh: al cumplirse 300s, o al hacerle kill,
  # termina el simulador y no deja huerfanos.
  nohup timeout --signal=TERM --kill-after=5 "$SIM_SECONDS" \
    "$ROOT/scripts/start-sim.sh" >>"$SIM_LOG" 2>&1 &
  echo $! > "$SIM_PIDFILE"
  sleep 0.3
  if ! sim_running; then
    echo "No se pudo arrancar el simulador. Revisa $SIM_LOG" >&2
    rm -f "$SIM_PIDFILE"
    return 1
  fi
  echo "Simulador en segundo plano por 5 minutos (pid $(cat "$SIM_PIDFILE"))."
  echo "Se detiene solo al cumplir 300s. Para pararlo antes: kill \$(cat $SIM_PIDFILE)"
  echo "Log: $SIM_LOG"
}

stop_sim_if_running() {
  if ! sim_running; then
    rm -f "$SIM_PIDFILE"
    return 0
  fi
  local pid i
  pid=$(cat "$SIM_PIDFILE")
  kill "$pid" 2>/dev/null || true
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.2
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi
  pkill -f "$ROOT/scripts/start-sim.sh" 2>/dev/null || true
  rm -f "$SIM_PIDFILE"
}

run_step() {
  local step="$1"
  case "$step" in
    1)
      banner 1 "Prod en vivo y humo en los tres ambientes"
      echo "Prueba /api/server en Prod (8082), UAT (8182) y Dev (8282)."
      scripts/smoke-test.sh http://127.0.0.1:8082
      scripts/smoke-test.sh http://127.0.0.1:8182
      scripts/smoke-test.sh http://127.0.0.1:8282
      ;;
    2)
      start_sim_background
      ;;
    3)
      banner 3 "Alarma de disponibilidad"
      echo "Publica Availability=0 en Prod, espera el estado ALARM y restaura Availability=1."
      echo "Mira la alarma en la consola de Floci, CloudWatch: http://172.17.0.2:4566"
      echo "Pulsa Refresh para ver avl-prod-traccar-availability pasar de OK a ALARM."
      scripts/fire-alarm.sh prod
      ;;
    4)
      banner 4 "Respaldo a S3"
      echo "Hace un pg_dump de Prod y lo sube al bucket de respaldos en Floci."
      scripts/backup.sh prod
      ;;
    5)
      banner 5 "Rollback (menos de 5 minutos)"
      echo "Vuelve el servicio ECS de Prod a la revision anterior de la task definition."
      echo "Objetivo: menos de 5 minutos (300s). Un cronometro visible ayuda en camara."
      local t0 elapsed rc
      t0=$(date +%s)
      set +e
      scripts/rollback.sh prod
      rc=$?
      set -e
      elapsed=$(( $(date +%s) - t0 ))
      if [ "$elapsed" -le 300 ]; then
        echo "Tiempo del paso: ${elapsed}s, dentro del limite de 5 minutos (300s)."
      else
        echo "Tiempo del paso: ${elapsed}s, por encima del limite de 5 minutos (300s)."
      fi
      return "$rc"
      ;;
    6)
      banner 6 "Restore en traccar_restore"
      echo "Descarga el ultimo respaldo y lo carga en la base traccar_restore, sin pisar la base de Prod."
      scripts/restore.sh prod
      ;;
    *)
      return 2
      ;;
  esac
}

run_all() {
  local t0 elapsed n
  t0=$(date +%s)
  echo "== Demo completa: pasos 1 a 6 =="
  echo "El simulador GPS (paso 2) corre 5 minutos en segundo plano y no bloquea los pasos siguientes."
  for n in 1 2 3 4 5 6; do
    if ! run_step "$n"; then
      elapsed=$(( $(date +%s) - t0 ))
      echo
      echo "La demo se detuvo en el paso ${n}. Tiempo transcurrido: ${elapsed}s."
      return 1
    fi
  done
  elapsed=$(( $(date +%s) - t0 ))
  echo
  echo "Demo completa (pasos 1 a 6). Tiempo total: ${elapsed}s."
  echo "El simulador GPS, si sigue arriba, se detiene solo al cumplir 5 minutos. Para pararlo antes: kill \$(cat $SIM_PIDFILE)"
}

STEP="${1:-}"
case "$STEP" in
  "")
    menu
    exit 0
    ;;
  --all|-all|all)
    run_all
    ;;
  1|2|3|4|5|6)
    run_step "$STEP"
    ;;
  *)
    echo "Paso invalido: ${STEP}" >&2
    echo >&2
    menu >&2
    exit 1
    ;;
esac
