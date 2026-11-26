#!/bin/bash
# Revierte el servicio ECS de un ambiente a la revision anterior de la
# task definition. Objetivo: menos de 5 minutos.
# Uso: scripts/rollback.sh [prod]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:-prod}"
AWS="$ROOT/scripts/aws-floci.sh"

CLUSTER=$("$ROOT/scripts/tf.sh" "$ENV" output -raw ecs_cluster_name)
SERVICE=$("$ROOT/scripts/tf.sh" "$ENV" output -raw ecs_service_name)
FAMILY=$("$ROOT/scripts/tf.sh" "$ENV" output -raw ecs_task_family)
WEB=$("$ROOT/scripts/tf.sh" "$ENV" output -raw web_url)

CURRENT=$("$AWS" ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].taskDefinition' --output text)
echo "Task definition actual: ${CURRENT}"

# Lista revisiones y elige la anterior a la que esta en el servicio.
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
  echo "No hay una revision anterior para ${FAMILY}." >&2
  exit 1
fi

echo "Retrocediendo a: ${PREV}"
"$AWS" ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
  --task-definition "$PREV" --force-new-deployment >/dev/null

echo "Esperando a que el servicio se estabilice..."
"$AWS" ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE" || true
"$ROOT/scripts/smoke-test.sh" "$WEB"
echo "Rollback completado."
