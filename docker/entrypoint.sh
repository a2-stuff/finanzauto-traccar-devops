#!/bin/sh
set -eu

# Si Floci o ECS no inyectan el secreto en DATABASE_PASSWORD,
# lo leemos de Secrets Manager o SSM usando el AWS CLI (imagen propia).
fetch_secret() {
  if [ -n "${DATABASE_PASSWORD:-}" ]; then
    return 0
  fi
  if [ -z "${DATABASE_PASSWORD_SECRET_ARN:-}${DATABASE_PASSWORD_SSM_PARAM:-}" ]; then
    echo "No hay DATABASE_PASSWORD ni referencia a Secrets Manager/SSM" >&2
    return 1
  fi
  AWS_ARGS="--region ${AWS_DEFAULT_REGION:-us-east-1}"
  if [ -n "${AWS_ENDPOINT_URL:-}" ]; then
    AWS_ARGS="$AWS_ARGS --endpoint-url ${AWS_ENDPOINT_URL}"
  fi
  if [ -n "${DATABASE_PASSWORD_SECRET_ARN:-}" ]; then
    DATABASE_PASSWORD=$(aws $AWS_ARGS secretsmanager get-secret-value \
      --secret-id "${DATABASE_PASSWORD_SECRET_ARN}" \
      --query SecretString --output text)
  else
    DATABASE_PASSWORD=$(aws $AWS_ARGS ssm get-parameter \
      --name "${DATABASE_PASSWORD_SSM_PARAM}" --with-decryption \
      --query Parameter.Value --output text)
  fi
  export DATABASE_PASSWORD
}

fetch_secret
export CONFIG_USE_ENVIRONMENT_VARIABLES=true
export DATABASE_DRIVER="${DATABASE_DRIVER:-org.postgresql.Driver}"
export DATABASE_USER="${DATABASE_USER:-traccar}"

exec /opt/traccar/jre/bin/java -jar /opt/traccar/tracker-server.jar /opt/traccar/conf/traccar.xml
