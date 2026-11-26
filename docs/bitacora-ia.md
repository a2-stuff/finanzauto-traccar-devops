# Bitacora de uso de IA

Herramientas: Grok Bot (asistente con acceso a la maquina y a conectores), documentacion oficial de Floci y de Traccar, y busquedas web para cruzar lo que la IA proponia. La IA esta permitida y se espera en esta prueba; lo que se evalua es el criterio.

## Prompts clave (5 a 10)

1. "Revisa los dos PDF de Finanzauto y arma un plan y un checklist para hacer la prueba en A2-wPRO."
2. "El Director de Tecnologia actualizo la prueba. Usa el PDF nuevo. Fluke se instala en esta maquina."
3. "Redacta las 5 respuestas del cuestionario en espanol, de 4-5 lineas, con hechos de mi hoja de vida. No inventes metricas."
4. "Prepara la herramienta en WSL Arch: Docker, Terraform, AWS CLI, Trivy, Checkov y Floci."
5. "Construye O1 a O9 y los bonus B1, B2 y B3 en el repo, con commits pequenos a mi nombre, sin subir nada a GitHub."
6. "No uses rayas largas en ningun archivo. El README debe abrir con badges de cada tecnologia usada."
7. "Deja un guion de video de maximo 10 minutos, fuera del repo, con comandos exactos."
8. "Configura OBS con DroidCam en 192.168.1.81:4747, sin tocar OBS si lo tengo abierto."

## Casos en los que la IA se equivoco o propuso algo inseguro

### 1. "Fluke" y el endpoint de salud de LocalStack

Que pedi: instalar "Fluke" y probar la herramienta del PDF.

Que propuso: tratar "Fluke" como un typo generico (Flux, Fluent Bit, kind) y, al arrancar Floci, consultar `http://localhost:4566/_localstack/health` como si Floci fuera LocalStack.

Como lo detecte: el PDF dice "Floci" y documenta `floci.io`. El health de LocalStack no es la referencia oficial. En el log del contenedor aparecio "AWS Local Emulator" y el health real de Floci respondio, pero el nombre y el endpoint habian salido de la costumbre de LocalStack, no de la documentacion.

Que hice: instale y use Floci (`floci/floci:latest`, puerto 4566), y deje constancia de no copiar a ciegas recetas de LocalStack.

### 2. AWS CLI de pacman y un salto de OpenSSL que no pedi

Que pedi: instalar AWS CLI v2 en Arch.

Que propuso / lo que salio del camino "oficial del distro": el paquete `aws-cli-v2` de extra, recien sincronizado, enlazaba `libcrypto.so.4` (OpenSSL 4.1 esta en el repo). En la distro seguia OpenSSL 3.6.2. La IA podria haber "arreglado" eso con `pacman -S openssl` (salto 3 a 4 en una maquina de uso diario).

Como lo detecte: `aws --version` fallo con `ImportError: libcrypto.so.4`. Comprobe `ldd` y `pacman -Si openssl` antes de tocar la libreria del sistema.

Que hice: quite el paquete roto e instale el instalador oficial de AWS CLI v2 (2.42.4), que trae sus propias librerias. No actualice OpenSSL del sistema.

### 3. Dockerfile que copiaba aws-cli de Alpine (musl) sobre la imagen Debian de Traccar

Que pedi: una imagen propia que pudiera leer secretos de Secrets Manager al arrancar, por si Floci no inyecta el campo `secrets` de la task definition (riesgo que el PDF ya avisa).

Que propuso: un stage `FROM alpine` y `COPY --from=tools /usr/bin/aws` hacia `traccar/traccar`.

Como lo detecte: Alpine usa musl y la imagen de Traccar que iba a usar es Debian/glibc. Ese binario no iba a funcionar. Lo revise antes de construir.

Que hice: reescribi el Dockerfile sobre `traccar/traccar:6.17.0-debian` e instale el AWS CLI oficial dentro de esa imagen.

### 4. Plugin de DroidCam para OBS 32 en un OBS 33

Que pedi: instalar el plugin de DroidCam para OBS.

Que salio por winget: `dev47apps.DroidCamOBSPlugin` 2.5.1, compilado para OBS 32.2. El instalador termino con codigo 2. OBS instalado es 33.0.3.

Como lo detecte: las notas de la version en GitHub listan un instalador aparte, `DroidCamOBS.Setup.2.5.1.obs33_1.exe`, para OBS 33.0.

Que hice: instale ese ejecutable oficial, no el paquete de winget.

### 5. Credenciales en la task definition

Que podria haber propuesto: meter la contrasena de Postgres como variable de entorno en claro en la task definition, o imprimir `terraform output` con el secreto.

Como lo evite: la contrasena la genera `random_password`, se guarda en Secrets Manager y el entrypoint la lee por ARN. Los outputs de Terraform no incluyen la contrasena. Las claves `test`/`test` en el provider y en el backend son las credenciales dummy de Floci, documentadas como tales, no secretos de la aplicacion.

## Que verifique a mano

- `docker run hello-world`, `aws --profile floci --endpoint-url http://localhost:4566` (S3, ECR, ECS, RDS, logs, Secrets Manager, SSM).
- `GET http://127.0.0.1:8082/api/server` desde WSL y desde Windows.
- `terraform fmt`, `validate` y apply contra Floci, mas Checkov y Trivy en local.
- Que `.env` esta en `.gitignore` y que `git log` no trae Co-authored-by ni un autor distinto a Alejandro Hirsch.
