# Tasks: Publicación automática del APK

**Input**: `/specs/009-publicacion-apk-ci/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Prerequisites**: plan.md, spec.md

**Tests**: el plan (R10) pide pruebas de shell con `ssh`/`scp`/`curl`/`apksigner` simulados, `shellcheck` y `actionlint`. Se escriben antes de la implementación de cada historia.

**Organization**: tareas agrupadas por historia de usuario. Rutas relativas a la raíz del repositorio.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias abiertas)
- **[Story]**: historia de usuario de la spec (US1–US4)
- Las tareas marcadas **(manual)** las hace Erick (GitHub o servidor); no se pueden automatizar desde el repositorio

---

## Phase 1: Setup

- [ ] T001 Crear `app/scripts/tests/test_scripts.sh` con el marco mínimo: directorio temporal por caso, `PATH` con `app/scripts/tests/stubs/` delante, función `assert_eq`/`assert_contains`, resumen y código de salida distinto de 0 si algo falla
- [ ] T002 [P] Crear los comandos simulados en `app/scripts/tests/stubs/`: `ssh`, `scp`, `curl` y `apksigner`, que escriben cada llamada en un registro y cuyo resultado se controla con variables (`STUB_SCP_FAIL`, `STUB_CURL_SHA`, `STUB_APKSIGNER_SHA`, etc.)
- [ ] T003 [P] Anotar en `specs/009-publicacion-apk-ci/research.md` (R9) la versión exacta de Flutter que se usa en local (`flutter --version`) y la versión de `build-tools` del runner `ubuntu-latest` (`ls $ANDROID_HOME/build-tools`), para fijarlas en el workflow

---

## Phase 2: Foundational (bloquea todas las historias)

- [ ] T004 [P] Crear `app/scripts/apk_cert_sha256.sh <apk>`: ejecuta `apksigner verify --print-certs`, imprime la huella SHA-256 del certificado en hex minúsculas sin `:`, sale 1 si el APK no está firmado o `apksigner` no existe (contracts/scripts.md)
- [ ] T005 Modificar `app/scripts/build_apk.sh`: pasar `--build-number=$(( $(date -u +%s) / 60 ))` a `flutter build apk` (admite `MYKCAL_BUILD_NUMBER`); imprimir `VERSION_CODE=<n>`; si hay `MYKCAL_EXPECTED_CERT_SHA256` comparar con `apk_cert_sha256.sh` y salir 1 si difiere (sin publicar); si no hay, avisar en español
- [ ] T006 Modificar `app/scripts/publish_apk.sh`: `~/.config/mykcal/publish.env` pasa a ser opcional (si falta, usar `PUBLISH_HOST` y `PUBLISH_DIR_PROD`/`PUBLISH_DIR_DEV` del entorno); `APK_BASE_URL` opcional; tras el `mv` descargar el enlace público y comparar el SHA-256 con el del APK local (FR-005), saliendo 1 si no coincide
- [ ] T007 Añadir a `app/scripts/tests/test_scripts.sh` los casos de la base: `MYKCAL_BUILD_NUMBER` llega a `flutter build` y `VERSION_CODE` crece entre dos llamadas separadas; huella distinta → `build_apk.sh` sale 1 antes de nada; `publish_apk.sh` funciona solo con variables de entorno (sin `publish.env`)

**Checkpoint**: los scripts compartidos funcionan en local y se prueban sin servicios reales.

---

## Phase 3: User Story 1 - Publicar producción al fusionar en `main` (P1) 🎯 MVP

**Goal**: un merge en `main` que toca `app/` compila, firma y publica el APK de producción sin intervención.

**Independent Test**: quickstart V1 y V2 (merge visible en `app/` → APK nuevo instalable encima; merge solo de backend → sin ejecución).

- [ ] T008 [US1] Añadir a `app/scripts/tests/test_scripts.sh` el caso feliz de publicación: sube a `mykcal.apk.tmp`, hace `mv` a `mykcal.apk`, la descarga simulada coincide en huella y sale 0 (FR-001, FR-005)
- [ ] T009 [US1] Crear `.github/workflows/publish-apk.yml` con `on.push.branches: [main]` y `paths: ['app/**']`, `permissions: contents: read`, `environment: production`, `concurrency: { group: publish-apk-prod, cancel-in-progress: false }`; pasos: `actions/checkout`, `actions/setup-java` (JDK 17), `subosito/flutter-action` con la versión de T003 y caché, decodificar `KEYSTORE_BASE64` en `$RUNNER_TEMP` y escribir `app/android/key.properties` desde los secretos, escribir `SSH_PRIVATE_KEY` (600) y `SSH_KNOWN_HOSTS`, exportar `MYKCAL_EXPECTED_CERT_SHA256` desde `vars.SIGNING_CERT_SHA256`, `app/scripts/build_apk.sh prod`, `app/scripts/publish_apk.sh prod`, y un último paso `if: always()` que borra keystore, `key.properties` y clave SSH. Sin `set -x` ni `pull_request`
- [ ] T010 [US1] (manual) Crear el entorno `production` en GitHub con los secretos `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS`, `PUBLISH_HOST`, `PUBLISH_DIR` y las variables `SIGNING_CERT_SHA256` (sacada con `apk_cert_sha256.sh` del APK ya publicado) y `APK_BASE_URL`; generar la clave SSH dedicada y autorizarla en el servidor solo para la carpeta del APK
- [ ] T011 [US1] Validar quickstart V1 y V2 con un merge real: APK descargable en menos de 15 min, instalación encima sin desinstalar, `versionCode` mayor que el anterior, y un merge solo de `backend/` sin ejecución (SC-001, SC-003)

**Checkpoint**: la publicación de producción funciona de extremo a extremo en el caso feliz.

---

## Phase 4: User Story 2 - Un fallo no rompe la descarga (P1)

**Goal**: cualquier fallo deja el APK anterior servido y la ejecución marcada como fallida con su causa.

**Independent Test**: quickstart V3 y V5 (fallo de compilación, de subida, de firma y de verificación; correo de GitHub; registros sin secretos).

- [ ] T012 [US2] Añadir a `app/scripts/tests/test_scripts.sh` los casos de fallo: `scp` falla a mitad (`STUB_SCP_FAIL`) → `mykcal.apk` intacto y `.tmp` eliminado; tamaño remoto distinto → sale 1 sin `mv`; verificación de huella fallida → se restaura `.prev` y sale 1; variable obligatoria ausente → el mensaje nombra la variable y no imprime ningún valor de secreto (FR-003, FR-004, FR-008)
- [ ] T013 [US2] Ampliar `app/scripts/publish_apk.sh`: tras `scp`, comprobar tamaño remoto igual al local; antes del `mv`, `cp -p mykcal.apk mykcal.apk.prev` si existe; `mv` atómico en el mismo volumen; si la verificación falla, restaurar `.prev` y salir 1; si va bien, borrar `.prev`; `trap` que elimina `mykcal.apk.tmp` ante cualquier error; mensajes en español sin valores de secretos
- [ ] T014 [US2] En `.github/workflows/publish-apk.yml` añadir, antes de compilar, un paso que compruebe que existen todos los secretos y variables de la configuración (data-model.md) y, si falta alguno, falle imprimiendo solo los **nombres** que faltan; añadir `::add-mask::` a los valores derivados que se escriban a archivos
- [ ] T015 [US2] Validar quickstart V3 y V5: forzar fallo de compilación, de subida (`PUBLISH_HOST` erróneo) y de firma (huella esperada distinta); comprobar enlace intacto, correo de GitHub por el fallo y registros de 3 ejecuciones sin contraseñas, claves ni keystore (SC-002, SC-004)

**Checkpoint**: la publicación es segura ante fallos.

---

## Phase 5: User Story 3 - Lanzar la publicación a mano (P2)

**Goal**: republicar sin fusionar, eligiendo entorno y, opcionalmente, commit de `main`.

**Independent Test**: quickstart V4 puntos 1 y 2.

- [ ] T016 [US3] En `.github/workflows/publish-apk.yml` añadir `on.workflow_dispatch` con entradas `environment` (`prod`|`dev`, por defecto `prod`) y `ref` (texto, opcional); resolver entorno de GitHub, flavor y grupo de concurrencia a partir de la entrada o de la rama; con `fetch-depth: 0`, validar con `git merge-base --is-ancestor <ref> origin/<rama del entorno>` y fallar antes de compilar con mensaje claro si el commit no pertenece a la rama; por defecto compilar la punta de la rama del entorno (FR-009)
- [ ] T017 [US3] Validar quickstart V4 (1 y 2): lanzar `prod` sin `ref` (se publica la punta de `main`), con un `ref` de `main` anterior (vuelta atrás) y con un `ref` de una rama de feature (falla antes de compilar)

**Checkpoint**: se puede publicar y volver atrás a mano.

---

## Phase 6: User Story 4 - Entorno de desarrollo (P3)

**Goal**: dejar preparado el APK de desarrollo sin afectar a producción y sin fallar mientras no exista.

**Independent Test**: quickstart V4 punto 3.

- [ ] T018 [US4] En `.github/workflows/publish-apk.yml` añadir `on.push.branches: [dev]` con `paths: ['app/**']`, `environment: development` y `flavor dev`; en el paso de comprobación de configuración, si el evento es `push` a `dev` y falta alguna configuración, terminar el job en verde con aviso «omitido: sin configuración» sin ejecutar compilación ni subida; si el evento es manual para `dev`, fallar con el mensaje que nombra lo que falta (FR-011); producción y desarrollo con grupos de concurrencia distintos
- [ ] T019 [US4] Validar quickstart V4 punto 3: lanzar a mano `dev` sin configurar (fallo claro, producción intacta) y hacer un `push` a `dev` sin configurar (ejecución en verde y omitida)

**Checkpoint**: el entorno de desarrollo queda preparado sin ruido.

---

## Phase 7: Polish & cross-cutting

- [ ] T020 [P] Crear `docs/deploy/publicar-apk.md`: lista de secretos y variables por entorno, cómo generar y restringir la clave SSH, cómo obtener `SIGNING_CERT_SHA256`, cómo lanzar la publicación a mano y cómo volver a una versión anterior (relanzar con un commit anterior de `main` o con el flujo manual) (FR-014)
- [ ] T021 [P] Actualizar `docs/deploy/produccion.md` (sección 4): indicar que el APK se publica solo al fusionar en `main` y enlazar a `publicar-apk.md`; dejar el flujo manual como alternativa
- [ ] T022 Pasar `shellcheck app/scripts/*.sh`, `actionlint .github/workflows/publish-apk.yml` y `bash app/scripts/tests/test_scripts.sh`; corregir lo que salga
- [ ] T023 Validar quickstart V6 (flujo manual con `build_apk.sh prod && publish_apk.sh prod` publica igual y con la misma verificación, FR-013) y repasar el quickstart completo
- [ ] T024 Actualizar `specs/009-publicacion-apk-ci/spec.md` (`Status: Implemented`) y abrir el PR de `009-publicacion-apk-ci` hacia `dev`

---

## Dependencies & Execution Order

- **Phase 1** → **Phase 2** → historias. Phase 2 bloquea todas.
- **US1** (T008–T011) es el MVP. T010 (manual) debe hacerse antes de T011 y de cualquier validación real posterior.
- **US2** depende de US1 (amplía `publish_apk.sh` y el workflow). **US3** y **US4** dependen de que exista el workflow (T009) y editan el mismo archivo, así que van en secuencia: T009 → T014 → T016 → T018.
- **Polish** al final; T020 y T021 pueden ir en paralelo con las validaciones.

### Dentro de cada historia

Pruebas (T008, T012) antes de la implementación (T009, T013). Las tareas de validación real (T011, T015, T017, T019) usan GitHub y el servidor reales.

## Parallel Opportunities

- Phase 1: T002 y T003 en paralelo (tras T001 para T002 si se comparte el marco).
- Phase 2: T004 en paralelo con T005/T006 (archivos distintos); T007 después de las tres.
- Phase 7: T020 y T021.
- `.github/workflows/publish-apk.yml` lo tocan T009, T014, T016 y T018: no se paralelizan.

## Implementation Strategy

1. **MVP**: Phases 1–3. Con eso `main` ya publica de forma automática en el caso feliz.
2. **Seguridad**: Phase 4 antes de fiarse del flujo (rollback y verificación). No fusionar a `main` sin haber hecho T012–T015.
3. **Comodidad**: Phase 5 (manual y vuelta atrás) y Phase 6 (dev, aplazada hasta que exista el entorno).
4. Cierre: Phase 7 y PR a `dev`. Aviso: GitHub solo muestra «Run workflow» y solo dispara `push` con el workflow ya presente en la rama por defecto (`main`). Por tanto la primera ejecución real (T011, T015, T017) ocurre al fusionar `dev` en `main`; antes de eso solo se puede validar con las pruebas de shell, `actionlint` y el flujo manual local (T023). Conviene fusionar primero un cambio pequeño y reversible en `app/` junto con el workflow.
