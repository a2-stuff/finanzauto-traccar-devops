# Informe de ejecucion

Prueba tecnica DevOps (AVL / Finanzauto). Maximo dos paginas. Tiempos reales, decisiones y riesgos si esto pasara a AWS de verdad.

## Tiempos reales (aprox., 26 nov 2026, hora de Colombia UTC-5)

- Lectura de la prueba, correos y PDF actualizado, plan y checklist: unos 45 min por la tarde.
- Herramientas en WSL Arch (Docker, Terraform 1.15.9, AWS CLI 2.42.4, Trivy, Checkov, Floci 2.5.0) y demo local de Traccar con Postgres: alrededor de 1 h.
- IaC (modulos Terraform, tres ambientes, scripts, workflows) y documentacion: a partir de las 18:00. La evidencia de apply, escaneos y scripts queda en la ultima seccion, despues de correrlo en A2-wPRO.
- Guion de video y OBS: en paralelo al cierre. El video en si no se grabo en esta sesion.

Si el total supera las 4 horas que estima el enunciado, lo registro con honestidad: el arranque de herramientas, el ajuste de AWS CLI en Arch y OBS/DroidCam no caben en el plan de 4 h. El PDF dice que la honestidad no se penaliza.

## Decisiones y alternativas que descarte

- Floci, no una cuenta real de AWS, como pide el enunciado. No use LocalStack.
- Terraform (no OpenTofu), porque ya estaba en los repos de Arch y encaja con el flujo de la prueba.
- Estado remoto en S3 y DynamoDB dentro de Floci, con un key por ambiente, en vez de solo estado local. El emulador, tal como corre hoy, guarda datos en memoria del contenedor: si se recrea Floci, se pierde el backend. Lo asumo y lo dejo escrito.
- Secretos en Secrets Manager (el ARN tambien en SSM). La task definition no lleva la contrasena en claro; el entrypoint de la imagen puede leer el secreto si Floci no inyecta el campo `secrets` (riesgo que el PDF ya menciona).
- Imagen propia a partir de Traccar 6.17.0-debian, etiquetada con el SHA, para escanearla y promoverla sin reconstruir.
- Puertos distintos por ambiente (Dev 8282/5255, UAT 8182/5155, Prod 8082/5055). Con 8 GB de RAM en WSL, Prod es la prioridad; Dev y UAT se pueden apagar si hace falta.
- En Checkov omiti controles de KMS/Insights poco realistas en un emulador local (`CKV_AWS_157`, `CKV_AWS_129`, `CKV_AWS_118`, `CKV_AWS_7`, `CKV2_AWS_5`). En AWS real no los dejaria de lado.
- El cuestionario queda fuera de este repo publico (carpeta Documents/CODE, archivo finanzauto-cuestionario.md), porque son respuestas personales de seleccion, no codigo de la plataforma.

## Riesgos si esto pasara a AWS real

- El backend y los datos de Floci no son durables como S3 o RDS reales. En AWS: bucket de estado con cifrado y versionado, tabla de locks, RDS con backups reales y retencion revisada.
- Las credenciales `test`/`test` y el endpoint `localhost:4566` no existen en AWS. Ahi se usa OIDC desde GitHub Actions, sin access keys estaticas, y endpoints reales.
- El runner auto-hospedado en un portatil no es un patron de produccion. El CD iria en runners de GitHub o en una cuenta aislada, con el rol minimo, y sin exponer el Docker de una maquina personal a workflows de terceros (la misma advertencia del PDF, todavia mas seria).
- La red ECS-a-RDS en el emulador puede pedir atajos (bridge, puertos en el host). En AWS usaria awsvpc, security groups y secretos inyectados por el agente de ECS, no un entrypoint contra un endpoint local.
- CloudWatch en Floci acepta metricas custom y alarmas; en la vida real hay que disenar agentes, retencion y costo.
- No hay WAF, HTTPS ni autenticacion federada delante de la UI. En un Prod real iria atras de un ALB con TLS y control de acceso.
- Tres ambientes vivos a la vez en 8 GB no equivalen a tres cuentas o VPCs. El codigo ya distingue recursos; en AWS se dimensiona con presupuesto, no con la RAM del portatil.

## Evidencia de esta ejecucion

Se completa despues de `terraform apply`, las pruebas de humo, backup/restore, alarma y rollback en Floci. Lo que no se alcance, o lo que exija la regla de los 20 minutos del emulador, se dice aqui sin maquillaje.

(pendiente de la corrida en A2-wPRO)
