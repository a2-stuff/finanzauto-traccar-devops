#!/bin/bash
# Revierte el servicio ECS de un ambiente a la revision anterior de la
# task definition. Objetivo: menos de 5 minutos.
# Uso: scripts/rollback.sh [prod]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:-prod}"
AWS="$ROOT/scripts/aws-floci.sh"
# shellcheck source=progress.sh
. "$ROOT/scripts/progress.sh"

progress_start 5

progress_step "Leyendo datos del ambiente ${ENV}"
OUTS=$("$ROOT/scripts/tf.sh" "$ENV" output -json)
CLUSTER=$(echo "$OUTS" | jq -r '.ecs_cluster_name.value')
SERVICE=$(echo "$OUTS" | jq -r '.ecs_service_name.value')
FAMILY=$(echo "$OUTS" | jq -r '.ecs_task_family.value')
WEB=$(echo "$OUTS" | jq -r '.web_url.value')
progress_ok

progress_step "Identificando la revision anterior"
CURRENT=$("$AWS" ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].taskDefinition' --output text)
echo "Task definition actual: ${CURRENT}"
ARNS=$("$AWS" ecs list-task-definitions --family-prefix "$FAMILY" --sort DESC --output text --query 'taskDefinitionArns[]')
PREV=""
FOUND=0
for arn in $ARNS; do
  if [ "$FOUND" = "1" ]; then
    PREV="$arn"
    break
  fi
  if [ "$arn" = "$CURRENT" ]; then
    FOUND=1
  fi
done
if [ -z "$PREV" ]; then
  progress_fail
  echo "No hay una revision anterior para ${FAMILY}." >&2
  exit 1
fi
echo "Retrocediendo a: ${PREV}"
progress_ok

progress_step "Actualizando el servicio ECS"
"$AWS" ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
  --task-definition "$PREV" --force-new-deployment >/dev/null
progress_ok

progress_step "Esperando a que el servicio se estabilice"
t0=$(date +%s)
stable=0
while true; do
  elapsed=$(( $(date +%s) - t0 ))
  read -r running desired ndep rollout dep_run dep_des < <("$AWS" ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" \
    --query 'services[0].[runningCount,desiredCount,length(deployments),deployments[0].rolloutState,deployments[0].runningCount,deployments[0].desiredCount]' \
    --output text 2>/dev/null || echo "0 0 0 ? 0 0")

  task_ok=0
  TASKS=$("$AWS" ecs list-tasks --cluster "$CLUSTER" --desired-status RUNNING \
    --output text --query 'taskArns[]' 2>/dev/null || true)
  if [ -n "${TASKS:-}" ] && [ "$TASKS" != "None" ]; then
    MATCH=$("$AWS" ecs describe-tasks --cluster "$CLUSTER" --tasks $TASKS \
      --query "tasks[?lastStatus=='RUNNING' && taskDefinitionArn=='${PREV}'].taskArn" \
      --output text 2>/dev/null || true)
    if [ -n "${MATCH:-}" ] && [ "$MATCH" != "None" ]; then
      task_ok=1
    fi
  fi

  health=0
  if curl -sfS --max-time 5 "${WEB%/}/api/server" 2>/dev/null | jq -e '.version' >/dev/null 2>&1; then
    health=1
  fi

  progress_wait "$elapsed" "estabilizacion ECS (running=${running:-?}/${desired:-?}, rollout=${rollout:-?}, revision=${task_ok}, api=${health})"

  # En Floci el rollout puede quedar IN_PROGRESS y el contenedor no se recicla.
  # Si el servicio ya apunta a la revision objetivo y la API responde, seguimos.
  CURDEF=$("$AWS" ecs describe-services --cluster "$CLUSTER" --services "$SERVICE"     --query 'services[0].taskDefinition' --output text 2>/dev/null || true)
  if [ "$health" = "1" ] && { [ "$task_ok" = "1" ] || [ "$CURDEF" = "$PREV" ]; }; then
    stable=1
    break
  fi
  if [ "${dep_run:-}" = "${dep_des:-}" ] && [ "${dep_des:-0}" != "0" ] &&      { [ "${rollout:-}" = "COMPLETED" ] || [ "${rollout:-}" = "None" ]; } &&      [ "$health" = "1" ]; then
    stable=1
    break
  fi
  if [ "$elapsed" -ge 180 ]; then
    echo "  aviso: no se confirmo estable en 180s; se continua con la prueba de humo."
    break
  fi
  sleep 5
done
if [ "$stable" = "1" ]; then
  progress_ok
else
  progress_ok "sin confirmacion ECS, se valida con humo"
fi

progress_step "Prueba de humo en ${WEB}"
"$ROOT/scripts/smoke-test.sh" "$WEB"
progress_ok
echo "Rollback completado."
progress_total
