# Informe de ejecucion

Prueba tecnica DevOps (AVL / Finanzauto). Maximo dos paginas. Tiempos reales, decisiones y riesgos si esto pasara a AWS de verdad.

## Tiempos reales (aprox., 26 nov 2026, hora de Colombia UTC-5)

- Lectura de la prueba y del PDF actualizado, plan y checklist: unos 45 min por la tarde.
- Herramientas en WSL Arch (Docker, Terraform 1.15.9, AWS CLI 2.42.4, Trivy, Checkov, Floci 2.5.0) y demo local de Traccar con Postgres: alrededor de 1 h.
- IaC (modulos Terraform, tres ambientes, scripts, workflows) y documentacion: a partir de las 18:00. Las pruebas contra Floci y el pipeline en GitHub se cerraron hacia las 20:09.

Si el total supera las 4 horas que estima el enunciado, lo registro con honestidad: el arranque de herramientas y el ajuste de AWS CLI en Arch no caben en el plan de 4 h. El PDF dice que la honestidad no se penaliza.

## Decisiones y alternativas que descarte

- Floci, no una cuenta real de AWS, como pide el enunciado. No use LocalStack.
- Terraform (no OpenTofu), porque ya estaba en los repos de Arch y encaja con el flujo de la prueba.
- Estado remoto en S3 y DynamoDB dentro de Floci, con un key por ambiente, en vez de solo estado local. El emulador, tal como corre hoy, guarda datos en memoria del contenedor: si se recrea Floci, se pierde el backend. Lo asumo y lo dejo escrito.
- Secretos en Secrets Manager (el ARN tambien en SSM). La task definition no lleva la contrasena en claro; el entrypoint de la imagen puede leer el secreto si Floci no inyecta el campo `secrets` (riesgo que el PDF ya menciona).
- Imagen propia a partir de Traccar 6.17.0-debian, etiquetada con el SHA, para escanearla y promoverla sin reconstruir.
- Puertos distintos por ambiente (Dev 8282/5255, UAT 8182/5155, Prod 8082/5055). Con 8 GB de RAM en WSL, Prod es la prioridad; Dev y UAT se pueden apagar si hace falta.
- En Checkov omiti controles poco realistas en un emulador local (`CKV_AWS_157`, `CKV_AWS_129`, `CKV_AWS_118`, `CKV_AWS_7`, `CKV2_AWS_5` y `CKV_AWS_336`, porque Traccar necesita escribir logs y datos en el contenedor). En AWS real no los dejaria de lado.

## Riesgos si esto pasara a AWS real

- El backend y los datos de Floci no son durables como S3 o RDS reales. En AWS: bucket de estado con cifrado y versionado, tabla de locks, RDS con backups reales y retencion revisada.
- Las credenciales `test`/`test` y el endpoint `localhost:4566` no existen en AWS. Ahi se usa OIDC desde GitHub Actions, sin access keys estaticas, y endpoints reales.
- El runner auto-hospedado en un portatil no es un patron de produccion. El CD iria en runners de GitHub o en una cuenta aislada, con el rol minimo, y sin exponer el Docker de una maquina personal a workflows de terceros (la misma advertencia del PDF, todavia mas seria).
- La red ECS-a-RDS en el emulador pide un atajo: Floci publica el RDS en un puerto proxy (7001/7002/7003) sobre la IP del propio emulador, no en el 5432 declarado del recurso. El IaC lee el Endpoint vivo de la API. En AWS usaria awsvpc, security groups y secretos inyectados por el agente de ECS, no un entrypoint contra un endpoint local.
- CloudWatch en Floci acepta metricas custom y alarmas; en la vida real hay que disenar agentes, retencion y costo.
- No hay WAF, HTTPS ni autenticacion federada delante de la UI. En un Prod real iria atras de un ALB con TLS y control de acceso.
- Tres ambientes vivos a la vez en 8 GB no equivalen a tres cuentas o VPCs. El codigo ya distingue recursos; en AWS se dimensiona con presupuesto, no con la RAM del portatil.

## Evidencia de esta ejecucion

Floci reporto los endpoints `172.17.0.2:7001` (dev), `:7002` (uat) y `:7003` (prod). El atributo `port=5432` del recurso hacia que JDBC y `pg_dump` hablaran con el contenedor de Floci (conexion rechazada) y Traccar salia con exit 1. Terraform ahora toma el puerto del Endpoint de la API y no lo devuelve a 5432 en cada apply. Tras el cambio, `/api/server` respondio 200 con Traccar 6.17.0 en los tres ambientes (Dev tardo unos 35 s en arrancar el esquema; por eso la prueba de humo del CD reintenta).

Pruebas locales contra Floci en A2-wPRO (26 nov 2026, UTC-5):

| Env | deploy | /api/server | smoke | GPS sim | alarm | rollback | backup/restore |
|-----|--------|-------------|-------|---------|-------|----------|----------------|
| dev | PASS (puerto 7001, 8282/5255) | PASS (6.17.0) | PASS | PASS (demo-osmand, 10.4255,-75.5465, caja de Cartagena) | PASS (ALARM en intento 1, restaurada) | PASS (142 s, humo OK) | PASS (S3; restore en `traccar_restore`: 52 tablas, 1 dispositivo, 5 posiciones) |
| uat | PASS (puerto 7002, 8182/5155, 49 s) | PASS (6.17.0) | PASS | PASS (10.4255,-75.5465) | PASS (ALARM en intento 1, restaurada) | PASS (133 s, humo OK) | PASS (52 tablas, 1 dispositivo, 5 posiciones) |
| prod | PASS (puerto 7003, 8082/5055, 50 s) | PASS (6.17.0) | PASS | PASS (10.424,-75.547) | PASS (ALARM en intento 1, restaurada) | PASS (137 s, humo OK) | PASS (52 tablas, 1 dispositivo, 5 posiciones) |

El rollback local registro una segunda revision saludable (con el puerto proxy correcto) y volvio a la anterior; el humo paso en los tres casos, siempre por debajo de 5 min. El simulador OsmAnd envio puntos en la caja 10.41-10.44, -75.56 a -75.53 y la API `/api/positions` los confirmo.

Pipeline en GitHub (commit `9bdb21f`):

- CI (fmt, validate, Checkov, Trivy): OK. https://github.com/a2-stuff/finanzauto-traccar-devops/actions/runs/45918342748
- CD (push a `main`): build OK, Promover a Dev OK, Promover a UAT OK, Promover a Prod queda en espera de aprobacion humana (no se aprobo). https://github.com/a2-stuff/finanzauto-traccar-devops/actions/runs/45918342854

La promocion con Environments y aprobacion de Prod solo se corre completa en GitHub; en local se simulo el mismo apply y las mismas pruebas de Prod, sin pulsar la aprobacion del Environment.
