#!/bin/bash
# Uso: scripts/tf.sh <dev|uat|prod> <init|validate|plan|apply|destroy|output> [args]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV="${1:?ambiente dev|uat|prod}"
CMD="${2:?comando terraform}"
shift 2
case "$ENV" in
  dev|uat|prod) ;;
  *) echo "Ambiente invalido: $ENV" >&2; exit 1 ;;
esac

export AWS_PROFILE="${AWS_PROFILE:-floci}"
export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_PAGER=""

TF_DIR="$ROOT/infra"
VAR_FILE="$TF_DIR/envs/${ENV}.tfvars"
BACKEND="$TF_DIR/envs/${ENV}.backend.hcl"
DATA="$TF_DIR/.terraform-${ENV}"

mkdir -p "$DATA"
cd "$TF_DIR"

case "$CMD" in
  init)
    terraform init -reconfigure -backend-config="$BACKEND" "$@"
    ;;
  validate)
    terraform init -backend=false -input=false >/dev/null
    terraform fmt -check -recursive
    terraform validate "$@"
    ;;
  plan)
    terraform init -reconfigure -backend-config="$BACKEND" -input=false >/dev/null
    terraform plan -var-file="$VAR_FILE" "$@"
    ;;
  apply)
    terraform init -reconfigure -backend-config="$BACKEND" -input=false >/dev/null
    terraform apply -var-file="$VAR_FILE" -auto-approve "$@"
    ;;
  destroy)
    terraform init -reconfigure -backend-config="$BACKEND" -input=false >/dev/null
    terraform destroy -var-file="$VAR_FILE" -auto-approve "$@"
    ;;
  output)
    terraform init -reconfigure -backend-config="$BACKEND" -input=false >/dev/null
    terraform output "$@"
    ;;
  *)
    echo "Comando no soportado: $CMD" >&2
    exit 1
    ;;
esac
