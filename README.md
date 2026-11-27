[![Terraform](https://img.shields.io/badge/Terraform-1.15-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://www.terraform.io)
[![AWS Floci](https://img.shields.io/badge/AWS-Floci%20emulator-FF9900?style=flat-square)](https://floci.io)
[![Amazon ECS](https://img.shields.io/badge/Amazon%20ECS-FF9900?style=flat-square)](https://aws.amazon.com/ecs/)
[![Amazon RDS](https://img.shields.io/badge/Amazon%20RDS-PostgreSQL-336791?style=flat-square&logo=postgresql&logoColor=white)](https://aws.amazon.com/rds/)
[![Amazon S3](https://img.shields.io/badge/Amazon%20S3-569A31?style=flat-square)](https://aws.amazon.com/s3/)
[![Secrets Manager](https://img.shields.io/badge/AWS_Secrets_Manager-DD344C?style=flat-square)](https://aws.amazon.com/secrets-manager/)
[![SSM](https://img.shields.io/badge/SSM%20Parameter%20Store-FF9900?style=flat-square)](https://docs.aws.amazon.com/systems-manager/)
[![CloudWatch](https://img.shields.io/badge/Amazon%20CloudWatch-FF4F8B?style=flat-square)](https://aws.amazon.com/cloudwatch/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat-square)](https://trivy.dev)
[![Checkov](https://img.shields.io/badge/Checkov-000000?style=flat-square)](https://www.checkov.io)
[![Dependabot](https://img.shields.io/badge/Dependabot-0260A4?style=flat-square&logo=dependabot&logoColor=white)](https://github.com/dependabot)
[![Traccar](https://img.shields.io/badge/Traccar-6.17-1F6FEB?style=flat-square)](https://www.traccar.org)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Mermaid](https://img.shields.io/badge/Mermaid-FF3670?style=flat-square&logo=mermaid&logoColor=white)](https://mermaid.js.org)

# Traccar en tres ambientes con Floci

Prueba tecnica en casa para el cargo de Ingeniero DevOps (AVL Mobility Solutions / Finanzauto). El objetivo es dejar Traccar con PostgreSQL en Dev, UAT y Prod, desplegado por pipelines, con secretos fuera del codigo, observabilidad, rollback y backups, todo sobre Floci (emulador de AWS en `http://localhost:4566`). Costo para el candidato: cero. No se usa una cuenta real de AWS.

## Requisitos cubiertos

- O1: Traccar como servicio ECS en Floci, con PostgreSQL en RDS emulado (no H2). Responde en el navegador y en `GET /api/server`.
- O2: Un solo codigo de Terraform para Dev, UAT y Prod, con variables y estado separados. Prod tiene mas CPU/memoria, mas retencion de logs y backups mas largos.
- O3: CI en cada pull request: `terraform fmt` y `validate`, escaneo de IaC (Checkov y Trivy), build de la imagen y escaneo de vulnerabilidades (Trivy). Si algo falla, no se debe fusionar.
- O4: CD construye una sola imagen, la etiqueta con el SHA del commit y la promueve Dev -> UAT -> Prod. Prod exige aprobacion manual (GitHub Environment).
- O5: Ninguna contrasena en el repositorio, en el historial ni en la imagen. La clave de la base vive en Secrets Manager (y el ARN en SSM).
- O6: Logs de Traccar en CloudWatch, un dashboard con tres senales (disponibilidad, errores y recursos) y una alarma que se dispara con una prueba controlada.
- O7: Rollback a la revision anterior de la task definition en menos de 5 minutos (`scripts/rollback.sh` o el workflow `Rollback`).
- O8: `pg_dump` de la base de Prod a S3 emulado y restauracion probada en la base `traccar_restore`.
- O9: Diagrama, README, bitacora de IA e informe de ejecucion.
- B1: Simulador GPS OsmAnd (`scripts/start-sim.sh`), apuntable a cualquier ambiente.
- B2: Prueba de humo despues de cada despliegue en `cd.yml`.
- B3: Dependabot para Docker, Terraform y GitHub Actions.

## Puertos locales

| Ambiente | UI Traccar | OsmAnd |
| -------- | ---------- | ------ |
| Dev      | http://127.0.0.1:8282 | http://127.0.0.1:5255 |
| UAT      | http://127.0.0.1:8182 | http://127.0.0.1:5155 |
| Prod     | http://127.0.0.1:8082 | http://127.0.0.1:5055 |

## Como levantar todo (pocos comandos)

Trabaja en WSL2 Arch (`archlinux`). Floci debe estar arriba en el puerto 4566.

```bash
cd /mnt/c/Users/A2/Documents/CODE/finanzauto-traccar
cp .env.example .env   # solo la primera vez; no lo confirmes en git

# 1) Backend de Terraform en Floci (bucket de estado y tabla de locks)
scripts/bootstrap-backend.sh

# 2) Imagen local etiquetada (en CI/CD se usa el SHA del commit)
docker build -t traccar-avl:local .

# 3) Desplegar ambientes (Prod es el prioritario si la RAM aprieta)
scripts/tf.sh prod apply -var='image=traccar-avl:local'
scripts/tf.sh uat apply  -var='image=traccar-avl:local'
scripts/tf.sh dev apply  -var='image=traccar-avl:local'

# 4) Prueba de humo
scripts/smoke-test.sh http://127.0.0.1:8082
```

Login de Traccar: usuario `admin`. La contrasena del demo local esta en `.env` (archivo ignorado por git), no en este README.

### Demo local (compose, opcional)

Si quieres Traccar+Postgres sin ECS, solo para desarrollo en el portatil:

```bash
docker compose up -d
scripts/smoke-test.sh http://127.0.0.1:8082
```

Este compose usa los puertos 8082 y 5055, los mismos que Prod en Floci. Detenlo antes de desplegar Prod: `docker compose stop`.

### Simulador GPS (B1)

```bash
# Prod (por defecto)
bash scripts/start-sim.sh

# UAT o Dev
TRACCAR_OSMAND_URL=http://127.0.0.1:5155 bash scripts/start-sim.sh
TRACCAR_OSMAND_URL=http://127.0.0.1:5255 bash scripts/start-sim.sh
```

Detener con Ctrl+C. En la UI, el dispositivo `demo-osmand` debe moverse en el mapa.

### Observabilidad, rollback y backups

```bash
# Publica metricas y dispara la alarma de disponibilidad (luego la restaura)
scripts/put-metrics.sh prod 1
scripts/fire-alarm.sh prod

# Rollback de Prod a la revision anterior de la task definition
scripts/rollback.sh prod

# Respaldo de Prod a S3 y restauracion en otra base
scripts/backup.sh prod
scripts/restore.sh prod
```

## Como desplegar a cada ambiente

El mismo codigo vive en `infra/`. Cambia solo el archivo de variables y el key del backend:

```bash
scripts/tf.sh dev plan
scripts/tf.sh uat apply -var='image=traccar-avl:<SHA>'
scripts/tf.sh prod apply -var='image=traccar-avl:<SHA>'
```

Prod se diferencia en `infra/envs/prod.tfvars`: 512 CPU / 1024 MiB, clase `db.t3.small`, 20 GiB de disco, 30 dias de logs, 7 dias de backup automatico de RDS y bucket de respaldos en S3. Dev es mas liviano (7 dias de logs, sin bucket de backups). UAT queda en el medio.

## Como hacer rollback

1. `scripts/rollback.sh prod` (o `dev` / `uat`).
2. El script toma la task definition anterior a la que esta en el servicio, hace `ecs update-service` y espera a que se estabilice.
3. Corre la prueba de humo sobre la UI de ese ambiente.
4. Desde GitHub: Actions > Rollback > Run workflow, ambiente `prod` (pide aprobacion del Environment).

Objetivo: menos de 5 minutos.

## Como restaurar un backup

1. `scripts/backup.sh prod` genera un `pg_dump` y lo sube a `s3://avl-prod-traccar-backups/prod-db/<stamp>.sql`.
2. `scripts/restore.sh prod` descarga el ultimo (o un URI `s3://...` que le pases) y lo carga en la base `traccar_restore`, sin pisar la base de Prod.
3. El script imprime cuantas tablas publicas quedaron en la base restaurada.

## Diseno en corto

- Un modulo de Terraform por concern: secretos, base, servicio ECS, observabilidad y backups.
- El estado remoto vive en S3+DynamoDB dentro de Floci (`avl-tfstate`, `avl-tflock`), con un key por ambiente.
- La imagen propia (`Dockerfile`) parte de `traccar/traccar:6.17.0-debian`. El entrypoint lee la contrasena de Secrets Manager si ECS no la inyecta (riesgo conocido del emulador).
- Las credenciales `test`/`test` son las de prueba de Floci, no llaves reales de AWS. No hay secretos de la aplicacion en git.

Diagrama: [docs/diagrama.md](docs/diagrama.md) y [docs/diagrama.svg](docs/diagrama.svg). Bitacora de IA: [docs/bitacora-ia.md](docs/bitacora-ia.md). Informe: [docs/informe.md](docs/informe.md).

## Preparar el repositorio en GitHub (manual)

No se crea ni se publica el repositorio desde este trabajo. Cuando quieras publicarlo:

1. Crea un repositorio **publico** vacio en tu cuenta de GitHub (sin README remoto que pise el local).
2. Agrega el remoto y publica `main`:
   `git remote add origin git@github.com:<tu-usuario>/<repo>.git && git push -u origin main`
3. En el repositorio, crea los Environments `dev`, `uat` y `prod`. En **prod**, activa required reviewers y asignate como revisor. Asi el job de Prod en `cd.yml` espera tu clic.
4. Secretos de GitHub (si el runner los necesita; Floci usa `test`/`test` en el perfil local `floci`): no subas contrasenas de la base. Esa clave la genera Terraform y vive en Secrets Manager.
5. Runner auto-hospedado, en esta misma maquina (WSL o Windows), porque Floci solo escucha en localhost. Registra el runner solo para **este** repositorio.
6. Regla de seguridad (enunciado de la prueba): si conectas un runner de GitHub a tu maquina, cuida que codigo de terceros no pueda ejecutarse en ella. No habilites el runner para forks ni para pull requests de desconocidos. Limitado a este repo y a ramas que tu controles.
7. Dependabot ya esta en `.github/dependabot.yml`; no requiere pasos extra una vez el repo es publico.

## Validar CI en local

```bash
cd infra
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
checkov -d . --framework terraform
trivy config .
# imagen
docker build -t traccar-avl:local ..
trivy image --severity CRITICAL --exit-code 1 traccar-avl:local
```
