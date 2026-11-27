# Bitacora de uso de IA

Herramientas: asistente con acceso a WSL en A2-wPRO, documentacion oficial de Floci y de Traccar, y busquedas web para contrastar versiones de acciones y proveedores. La IA esta permitida en esta prueba; lo que se evalua es el criterio tecnico (revisar, rechazar o corregir lo generado, y verificarlo con comandos).

## Prompts tecnicos clave

1. Revisar el PDF actualizado de la prueba tecnica DevOps AVL/Finanzauto y construir O1 a O9 mas B1, B2 y B3 como codigo, no como un informe suelto.
2. Dejar la toolchain en WSL Arch (Docker Engine, Terraform, AWS CLI v2, Trivy, Checkov, jq) y usar Floci en localhost:4566 como emulador de AWS.
3. Modelar la infraestructura en Terraform con modulos (secretos, base de datos, servicio, observabilidad, respaldos) y tres ambientes (dev, uat, prod) con estado y variables separados.
4. Disenar GitHub Actions: CI con fmt, validate, Checkov y Trivy; CD que promueve la misma imagen etiquetada con el SHA; aprobacion humana en Prod; runner self-hosted acotado al repo, etiqueta `floci`, sin correr esos jobs en PRs de forks; Dependabot.
5. Probar de verdad contra Floci: `terraform apply` por ambiente, pruebas de humo en `/api/server`, simulador OsmAnd, disparo de alarma en CloudWatch, rollback a la revision anterior de ECS (objetivo menor a 5 minutos) y `pg_dump` a S3 con restore en otra base.
6. Hacer commits pequenos, sin secretos en el historial, y un README en espanol que abre con badges de cada tecnologia usada. Prohibido usar rayas largas (em dash o en dash).
7. Antes de publicar: `.gitignore` exhaustivo, `git ls-files` sin `.env`, `trivy fs --scanners secret` sobre el arbol versionado, y un barrido de `git log --all -p` para la contrasena de admin y para llaves.

## 1. Layout de Terraform: modulos y ambientes

Que se pidio: un arbol reutilizable, un backend S3 con locks en DynamoDB sobre Floci, y variables distintas por ambiente (CPU, memoria, tamano de RDS, puertos, retencion de logs y backups).

Que se genero: `infra/modules/{secrets,database,service,observability,backup}`, `infra/envs/{dev,uat,prod}.tfvars` y los `*.backend.hcl` (bucket `avl-tfstate`, keys `dev|uat|prod/terraform.tfstate`, tabla `avl-tflock`). El wrapper `scripts/tf.sh` elige tfvars y backend segun el ambiente. Los puertos quedaron en Dev 8282/5255, UAT 8182/5155 y Prod 8082/5055.

Que se corrigio o rechazo: el script creaba `infra/.terraform-${ENV}` pero no exportaba `TF_DATA_DIR`, asi que los tres ambientes habrian compartido el mismo `.terraform/` y el backend se pisaria al cambiar de entorno. Se exporto `TF_DATA_DIR` y se anadio `.terraform-*/` al `.gitignore`. `terraform fmt -check` fallo en `envs/*.tfvars`, `main.tf` y `providers.tf`; se aplico `terraform fmt -recursive` y se versiono `infra/.terraform.lock.hcl` (AWS 5.100.0, random 3.9.1).

Como se verifico:
- `terraform -chdir=infra fmt -check -recursive` termino en `FMT_OK`.
- `terraform -chdir=infra init -backend=false -input=false` y `terraform validate` imprimieron `Success! The configuration is valid` (`VALIDATE_OK`).
- `scripts/bootstrap-backend.sh` creo `avl-tfstate` (HeadBucket, region us-east-1) y la tabla `avl-tflock` en estado `ACTIVE`.
- `scripts/tf.sh dev apply -var='image=traccar-avl:local'` completo en 262 s: `Apply complete! Resources: 19 added, 0 changed, 0 destroyed.` Outputs: `web_url=http://127.0.0.1:8282`, `osmand_url=http://127.0.0.1:5255`, `db_address=172.17.0.2`, `db_port=5432`, `ecs_cluster_name=avl-dev-cluster`, `backup_bucket=avl-dev-traccar-backups`. El provider aviso de parametros deprecados en `endpoints` (`logs` vs `cloudwatchlogs`); no bloqueo el apply.

## 2. CI/CD en GitHub Actions

Que se pidio: CI en `ubuntu-latest` con fmt, validate, Checkov y Trivy; CD en runner self-hosted porque Floci solo escucha en localhost; promocion Dev -> UAT -> Prod de la misma imagen `traccar-avl:${GITHUB_SHA}`; Environment `prod` con revisor obligatorio; Dependabot para docker, terraform y github-actions.

Que se genero: `.github/workflows/ci.yml`, `cd.yml`, `rollback.yml` y `.github/dependabot.yml`. El job de build etiqueta la imagen con el SHA y no recompila en los deploys siguientes. Los workflows de CD y rollback usan `runs-on: [self-hosted, floci]` y un `if` que evita ejecutarlos cuando el PR viene de un fork.

Que se corrigio o rechazo:
- Checkov en local, primera pasada: 24 passed, 16 failed. Se endurecio el codigo (Container Insights, `copy_tags_to_snapshot`, SSM `SecureString`, bucket con CMK, versionado, lifecycle, aborto de multipart) y se dejo un `.checkov.yaml` con omisiones explicitas de controles poco realistas en el emulador (IAM auth en RDS, deletion protection, rotacion automatica, CRR, access logging de S3, entre otros). Tras eso siguieron 3 fallos: `CKV_AWS_300` (el aborto multipart no se detectaba en la misma regla que la expiracion), `CKV_AWS_337` (SSM sin CMK) y `CKV2_AWS_64` (KMS sin policy). Se anadio una regla dedicada de aborto, una CMK para SSM y una policy. Un intento con `Principal = "*"` disparo `CKV_AWS_33`; se cambio a `arn:aws:iam::000000000000:root` (account que Floci reporta).
- Trivy config: fallo `AVD-AWS-0132` (S3 sin CMK) y `AVD-AWS-0180` (RDS publico). Se cifro el bucket con KMS. El acceso publico de RDS se dejo y se documento en `.trivyignore`, porque `pg_dump` desde el host tiene que alcanzar el Postgres de Floci.
- En GitHub, `aquasecurity/trivy-action@v0.28.0` fallo en 2 s en ambos jobs del run `45913427500`: `Unable to resolve action aquasecurity/setup-trivy@v0.2.1`. Un pin a `aquasecurity/trivy-action@0.36.0` (sin el prefijo `v`) tambien fallo: `unable to find version 0.36.0` (run `45913913706`). Se dejo de usar la action y se instalo Trivy 0.76.2 con el instalador oficial dentro del job (commit `8a73044`).
- El job CD "Promover a Dev" del run `45914553034` fallo en 8 s con exit 126: `scripts/tf.sh: Permission denied`. `git ls-files -s scripts` mostro esos archivos en modo `100644`, no `100755`. El `.gitattributes` ya tenia `*.sh text eol=lf` y los scripts en el arbol estan en LF (sin CRLF). La causa del 126 es el bit de ejecucion en el indice, no los finales de linea.

Como se verifico en local: `FMT_OK`, `VALIDATE_OK`, `CHECKOV_OK` (36 passed, 0 failed), `TRIVY_CONFIG_OK` (0 hallazgos HIGH/CRITICAL, con ignore de `AVD-AWS-0180`). El escaneo de imagen con Trivy en local no se completo: la descarga de la DB de vulnerabilidades (~960 MiB) iba a ~1 MiB/s y se interrumpio. En GitHub, el CI del commit `8a73044` (run `45914553118`) paso el job de IaC en 39 s. El job de imagen seguia en curso al momento de esa lectura. El CD del mismo commit construyo la imagen y fallo en "Promover a Dev" por el 126 citado. El Environment `prod` exige revisor `a2-stuff`; no se aprobo ese paso.

## 3. Quirks de Floci y correcciones

Que se pidio: usar el emulador del PDF en esta maquina, no un atajo conceptual.

Que se genero: contenedor `floci/floci:latest` en `0.0.0.0:4566`, perfil/claves dummy `test`/`test`, region `us-east-1`, y providers/backends apuntando a ese endpoint. El health en `/_localstack/health` respondio `version=2.5.0`, `edition=community`, con `ecs` y `rds` en `running`. Floci levanta Postgres y las tasks de ECS como contenedores Docker reales (se vieron `floci-aws-rds-...` y `floci-aws-ecs-...-traccar`).

Que se corrigio o rechazo:
- El nombre "Fluke" (dictado) se malinterpreto al inicio como un typo generico. El PDF dice Floci (`floci.io`). Se instalo Floci, no otra herramienta.
- Consultar solo recetas de LocalStack. El path `/_localstack/health` respondio, pero no se tomo como referencia oficial ni se asumio paridad total de APIs.
- Instalar `aws-cli-v2` de pacman: el paquete enlazaba `libcrypto.so.4` (OpenSSL 4.1 en el repo) mientras el sistema tenia OpenSSL 3.6.2. Se rechazo actualizar OpenSSL del sistema. Se desinstalo el paquete roto y se instalo AWS CLI oficial 2.42.4 (`aws-cli/2.42.4` en `/usr/local/bin/aws`).
- Recrear el contenedor de Floci a la ligera: el almacenamiento era in-memory, un recreate borra tfstate y recursos. No se recreo durante las pruebas.

Como se verifico: `docker ps` mostro `floci` healthy en 4566; `curl -sS -m 5 http://127.0.0.1:4566/_localstack/health` devolvio el JSON anterior; `scripts/aws-floci.sh` opero S3, DynamoDB, ECS, RDS, Secrets Manager, SSM, CloudWatch y logs. El apply de Dev materializo 19 recursos. Terraform reporto `db_address=172.17.0.2`. En una inspeccion posterior de Docker, `172.17.0.2` era la IP del contenedor `floci`, no la de los contenedores RDS (`172.17.0.4` y `172.17.0.6`). Las tasks ECS tenian `DATABASE_URL=jdbc:postgresql://172.17.0.2:5432/traccar`. `pg_dump` a `172.17.0.2:5432` fallo con `Connection refused`. Ese desajuste de IP es un hallazgo verificado; el arreglo en el codigo todavia no se habia aplicado al redactar esta nota.

## 4. Imagen Docker de Traccar y PostgreSQL

Que se pidio: Traccar 6.17.0 con PostgreSQL 16 (no H2), imagen propia capaz de leer el secreto si ECS/Floci no inyectan `DATABASE_PASSWORD`, y un compose local para el demo.

Que se genero: `Dockerfile` `FROM traccar/traccar:6.17.0-debian`, instalacion del AWS CLI oficial, `docker/entrypoint.sh` que consulta Secrets Manager o SSM, `docker-compose.yml` (puertos 8082/5055, volumen nombrado de Postgres). La imagen de trabajo se etiqueto `traccar-avl:local`.

Que se corrigio o rechazo: un stage `FROM alpine` que copiaba `/usr/bin/aws` (musl) sobre la imagen Debian (glibc). Se rechazo antes de confiar en ese binario. El Dockerfile quedo solo sobre la variante debian con el instalador oficial.

Como se verifico: `docker build -t traccar-avl:local .` termino `Successfully built 4190fae1dfec` / `DOCKER_BUILD_OK` (~1.02 GB). El compose local, antes de detenerlo para liberar 8082/5055, respondia `GET http://127.0.0.1:8082/api/server` con HTTP 200 desde WSL y desde Windows. En ECS/Floci la misma imagen se enlazo a 8282/5255. El contenedor a veces aparecia `Up` unos segundos y luego `Exited (1)`. `docker logs` mostro sobre todo advertencias de `sun.misc.Unsafe` (Guice). El inspect del env confirmo `DATABASE_PASSWORD` inyectada (longitud 24, el valor no se imprime) y `DATABASE_URL` apuntando a `172.17.0.2:5432`. `curl` a `http://127.0.0.1:8282/api/server` devolvio `Connection refused` o `curl: (56) Recv failure: Connection reset by peer` mientras el proceso moria. No se declara el servicio estable en 8282 hasta que `/api/server` devuelva 200 de forma repetible.

## 5. Secretos en Secrets Manager y SSM

Que se pidio: no poner la contrasena de Postgres en claro en la task definition ni en outputs de Terraform, y no commitear `.env` ni secretos reales.

Que se genero: `random_password` (24 caracteres, especiales `-_`), `aws_secretsmanager_secret` + version, parametro SSM con el ARN (`SecureString` cifrado con CMK), inyeccion `secrets.valueFrom` en la task y fallback en el entrypoint (`DATABASE_PASSWORD_SECRET_ARN`). Las claves `test`/`test` del provider, del backend y de la task son las credenciales dummy documentadas de Floci, no secretos de la aplicacion. El output `db_password` del modulo esta marcado `sensitive = true` y no se exporta en el root module.

Que se rechazo: imprimir `terraform output` del password, o meter `DATABASE_PASSWORD` en texto plano en `container_definitions`.

Como se verifico: `git ls-files --error-unmatch .env` no encuentra el archivo; `.gitignore` lo cubre con `*.env` (y deja `!.env.example`). `git log --all -p` no contiene el valor de `TRACCAR_ADMIN_PASSWORD` del `.env` local (`ADMIN_PASSWORD_HISTORY_CLEAN`, `ADMIN_PASSWORD_TRACKED_CLEAN`). `trivy fs --scanners secret` sobre un `git archive` de HEAD: `TRIVY_SECRET_HIT_COUNT=0`. En el apply de Dev, Terraform creo el secreto `avl-dev/traccar/db-password-...` y el parametro `/avl-dev/traccar/db-secret-arn` sin imprimir el valor.

## 6. Alarma de CloudWatch

Que se pidio: una prueba controlada de la alarma de disponibilidad (O6), no un incidente real.

Que se genero: metrica `AVL/Traccar` / `Availability` con dimension `Environment`, alarma `avl-${env}-traccar-availability` (`LessThanThreshold`, period 60, `treat_missing_data=breaching`), dashboard con disponibilidad, errores y CPU, mas `scripts/put-metrics.sh` y `scripts/fire-alarm.sh`.

Como se verifico en Dev, sobre el recurso real creado por Terraform: `scripts/fire-alarm.sh dev` publico `Availability=0`, en el intento 1 el estado ya era `ALARM`, se restauro `Availability=1` y el script imprimio `Alarma disparada y restaurada.` Resultado: `dev alarm PASS`.

## 7. Rollback de ECS y backup/restore con pg_dump

Que se pidio: volver a la revision anterior de la task definition en menos de 5 minutos, y un dump a S3 restaurado en una base aparte (`traccar_restore`) con comprobacion de datos.

Que se genero: `scripts/rollback.sh` (lista revisiones, elige la anterior a la del servicio, `update-service`, espera `services-stable`, lanza el smoke test). `scripts/backup.sh` y `scripts/restore.sh` leen host/puerto/ARN desde `terraform output` (sin imprimir la contrasena), suben a `s3://${bucket}/${env}-db/<stamp>.sql` y restauran en `traccar_restore`, contando tablas, `tc_devices` y `tc_positions`. Si el host no tiene `psql`/`pg_dump`, `scripts/pg-client.sh` usa `postgres:16` con `--network host`.

Como se verifico en Dev: solo habia una revision; se registro `avl-dev-traccar:2` (marker `AVL_REVISION_MARK=2`) y el servicio paso a `:2` (`revisions_after=2`). `scripts/rollback.sh dev` retrocedio a `avl-dev-traccar:1` y luego el smoke fallo con `curl: (56) Recv failure: Connection reset by peer`. Tiempo: 132 s (dentro de 5 minutos de reloj, pero el criterio de exito incluye la prueba de humo). Resultado: `dev rollback FAIL`. `scripts/backup.sh dev` fallo: `pg_dump: error: connection to server at "172.17.0.2", port 5432 failed: Connection refused`. Resultado: `dev backup_restore FAIL`.

## 8. Simulador GPS OsmAnd y prueba de humo

Que se pidio: un simulador que envie puntos cerca del Centro Historico de Cartagena al puerto OsmAnd de cada ambiente, y un smoke test de `GET /api/server` que compruebe `version` con `jq`.

Que se genero: `scripts/start-sim.sh` (dispositivo `demo-osmand`, URL configurable: 5055 prod, 5155 uat, 5255 dev) y `scripts/smoke-test.sh`.

Como se verifico: el smoke y el sim sobre el compose local en 8082/5055 funcionaron antes de bajar el compose (HTTP 200 en `/api/server`). Contra el servicio ECS de Dev, `scripts/smoke-test.sh http://127.0.0.1:8282` fallo (`connection reset`). El bloque de GPS se omitio porque la API no respondia (`dev gps_sim FAIL skipped, api down`). No se afirma que las posiciones quedaran grabadas en el Traccar de Floci en esa pasada.

## 9. Dependabot, badges y escaneo de seguridad previo al push

Que se pidio: Dependabot, un `.gitignore` que cubra secretos, dumps, tfstate, videos, llaves, runner y documentos privados, un barrido de secretos antes de publicar, y badges de shields.io que se vean bien en el README.

Que se genero: `.github/dependabot.yml`, `.gitignore` ampliado, `.trivyignore`, `.checkov.yaml`, y un escaneo sobre el historial y sobre `git archive` (sin incluir `.env`). El README abre con una fila de badges. El de Secrets Manager usaba `logo=amazoniam`, un slug que shields.io no pinta (el SVG salia 200 pero sin `<image>` de logo). Se cambio a `https://img.shields.io/badge/AWS_Secrets_Manager-DD344C?style=flat-square` (sin logo). El mismo problema se vio en otros slugs invalidos (`amazon-aws`, `amazonecs`, `amazons3`, `amazoncloudwatch`, `aquasecurity`); se les quito el parametro `logo`. Los logos que si se incrustan (`terraform`, `postgresql`, `docker`, `githubactions`, `dependabot`, `gnubash`, `mermaid`) se dejaron.

Como se verifico:  se curlearon las 16 URLs del README; todas devolvieron HTTP 200, `Content` SVG y sin texto de error. 57 archivos estaban en el indice al primer escaneo; `.env` sigue ignorado; no hay AKIA, bloques de llave privada ni el valor de la contrasena de admin en `git log --all -p`. Los unicos `AWS_SECRET_ACCESS_KEY=test` son los placeholders de Floci. `trivy fs --scanners secret` sobre el arbol versionado: 0 hallazgos. Quedaron abiertas PRs de Dependabot (por ejemplo AWS provider 5.x a 6.x y `actions/checkout` 4 a 7) sin fusionar.
