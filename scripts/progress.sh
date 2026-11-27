#!/bin/bash
# Funciones de progreso para los scripts de operacion.
# Uso: . "$ROOT/scripts/progress.sh"

progress_start() {
  PROGRESS_TOTAL="${1:?total de pasos}"
  PROGRESS_N=0
  PROGRESS_T0=$(date +%s)
  PROGRESS_STEP_T0=$PROGRESS_T0
  PROGRESS_MSG=""
}

progress_now() {
  date '+%H:%M:%S'
}

progress_step() {
  PROGRESS_N=$((PROGRESS_N + 1))
  PROGRESS_MSG="$1"
  PROGRESS_STEP_T0=$(date +%s)
  echo "[${PROGRESS_N}/${PROGRESS_TOTAL}] $(progress_now) ${PROGRESS_MSG}..."
}

progress_ok() {
  local d=$(( $(date +%s) - PROGRESS_STEP_T0 ))
  local extra="${1:-}"
  if [ -n "$extra" ]; then
    echo "[${PROGRESS_N}/${PROGRESS_TOTAL}] $(progress_now) ${PROGRESS_MSG}: OK en ${d}s. ${extra}"
  else
    echo "[${PROGRESS_N}/${PROGRESS_TOTAL}] $(progress_now) ${PROGRESS_MSG}: OK en ${d}s"
  fi
}

progress_fail() {
  local d=$(( $(date +%s) - PROGRESS_STEP_T0 ))
  echo "[${PROGRESS_N}/${PROGRESS_TOTAL}] $(progress_now) ${PROGRESS_MSG}: FALLO en ${d}s" >&2
}

progress_wait() {
  echo "  esperando ${2} ... ${1}s"
}

progress_total() {
  local d=$(( $(date +%s) - PROGRESS_T0 ))
  echo "Tiempo total: ${d}s"
}
