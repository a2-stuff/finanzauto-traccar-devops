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
export TF_IN_AUTOMATION=1
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$ROOT/infra/.terraform-plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

TF_DIR="$ROOT/infra"
VAR_FILE="$TF_DIR/envs/${ENV}.tfvars"
BACKEND="$TF_DIR/envs/${ENV}.backend.hcl"
DATA="$TF_DIR/.terraform-${ENV}"
export TF_DATA_DIR="$DATA"

mkdir -p "$DATA"
cd "$TF_DIR"

# init -reconfigure en cada llamada era el cuello de botella (~30s o mas).
# Se reutiliza el backend ya inicializado salvo que falte o cambie el .hcl.
ensure_init() {
  local force="${1:-}"
  local hashfile="$DATA/.backend.hash"
  local hash
  hash=$(sha256sum "$BACKEND" | awk '{print $1}')
  local need=0
  if [ "$force" = "reconfigure" ]; then
    need=1
  elif [ ! -f "$DATA/terraform.tfstate" ]; then
    need=1
  elif [ "$(cat "$hashfile" 2>/dev/null || true)" != "$hash" ]; then
    need=1
  fi
  if [ "$need" = "1" ]; then
    echo "Inicializando Terraform para ${ENV}..." >&2
    terraform init -reconfigure -backend-config="$BACKEND" -input=false >&2
    echo "$hash" > "$hashfile"
  fi
}

case "$CMD" in
  init)
    ensure_init reconfigure
    ;;
  validate)
    terraform init -backend=false -input=false >/dev/null
    terraform fmt -check -recursive
    terraform validate "$@"
    ;;
  plan)
    ensure_init
    terraform plan -var-file="$VAR_FILE" -input=false "$@"
    ;;
  apply)
    ensure_init
    terraform apply -var-file="$VAR_FILE" -input=false -auto-approve "$@"
    ;;
  destroy)
    ensure_init
    terraform destroy -var-file="$VAR_FILE" -input=false -auto-approve "$@"
    ;;
  output)
    ensure_init
    terraform output "$@"
    ;;
  *)
    echo "Comando no soportado: $CMD" >&2
    exit 1
    ;;
esac
