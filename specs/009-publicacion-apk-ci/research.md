# Research: Publicación automática del APK (Phase 0)

Sin `NEEDS CLARIFICATION`: la spec se aclaró el 2026-11-25. Decisiones de diseño:

## R1 — La lógica va en los scripts, el workflow solo orquesta (FR-013)

**Decisión**: `publish-apk.yml` instala herramientas, prepara secretos y llama a
`build_apk.sh <flavor>` y `publish_apk.sh <flavor>`. `publish_apk.sh` deja de exigir
`~/.config/mykcal/publish.env`: si falta, usa las variables de entorno `PUBLISH_HOST` y
`PUBLISH_DIR_PROD`/`PUBLISH_DIR_DEV`.

**Razón**: un solo código para el portátil y el CI garantiza la misma atomicidad y se prueba sin
GitHub (principios VI y VII). **Alternativa descartada**: lógica duplicada en el YAML (divergiría).

## R2 — Disparadores y filtro de `app/` (FR-001, 002, 009, 012)

**Decisión**: `push` a `main` con `paths: ['app/**']` → prod; `push` a `dev` con el mismo filtro → dev;
`workflow_dispatch` con entrada `environment` (`prod`|`dev`) y `ref` (commit, por defecto la
punta de la rama del entorno). Sin disparador `pull_request` ni ramas de feature.

**Razón**: el filtro nativo de rutas cubre «solo si cambia la app». Un merge que solo toca
backend o documentación no arranca el workflow (US1.4).

## R3 — Número de versión por hora de compilación (FR-006)

**Decisión**: `build_apk.sh` pasa `--build-number=$(( $(date -u +%s) / 60 ))` a `flutter build apk`
(admite `MYKCAL_BUILD_NUMBER` para pruebas). Hoy ≈ 29,7 millones; el límite de Android es
2.100.000.000, sin riesgo práctico. `versionName` sigue siendo el de `pubspec.yaml` (1.0.0).

**Razón**: aclaración del 2026-11-25; funciona igual en CI y en el portátil sin estado compartido.
**Riesgo**: dos compilaciones en el mismo minuto empatan; la concurrencia (R6) y el uso de un solo
mantenedor lo hacen inviable en la práctica.

## R4 — Comprobación de la huella de firma (FR-007)

**Decisión**: tras compilar, `apk_cert_sha256.sh` obtiene la huella SHA-256 del certificado con
`apksigner verify --print-certs` y `build_apk.sh`/el workflow la compara con la variable del
repositorio `SIGNING_CERT_SHA256` (no secreta). Si difiere, falla antes de subir. En local, la
huella esperada se pasa por `MYKCAL_EXPECTED_CERT_SHA256` (opcional, con aviso si falta).

**Razón**: aclaración del 2026-11-25; independiente del estado del servidor.

## R5 — Subida atómica, verificación y retorno (FR-003, 004, 005)

**Decisión**: en el servidor, `publish_apk.sh`:
1. `scp` a `mykcal.apk.tmp`; comprueba tamaño remoto igual al local.
2. `ssh`: si existe `mykcal.apk`, `cp -p` a `mykcal.apk.prev`; después `mv mykcal.apk.tmp mykcal.apk`
   (renombrado atómico en el mismo volumen).
3. Descarga el enlace público y compara el SHA-256 con el del APK local.
4. Si la verificación falla, restaura `mykcal.apk.prev` → `mykcal.apk` y sale con error.
5. Si va bien, borra `mykcal.apk.prev`. Un fallo antes del paso 2 elimina `mykcal.apk.tmp`.

**Razón**: el enlace nunca sirve un archivo parcial (renombrado atómico) y la comprobación
posterior no deja una versión mala publicada. **Alternativa descartada**: guardar historial de APK
(la spec dice que no).

## R6 — Concurrencia (FR-010)

**Decisión**: `concurrency: { group: publish-apk-${{ entorno }}, cancel-in-progress: false }`. Las
ejecuciones del mismo entorno se encolan; GitHub conserva solo la pendiente más reciente, de modo
que el enlace acaba sirviendo el último merge. Producción y desarrollo no se bloquean entre sí.

## R7 — Secretos, entornos de GitHub y registros (FR-008, 011)

**Decisión**: dos *Environments* de GitHub, `production` y `development`, cada uno con sus secretos:
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `SSH_PRIVATE_KEY`,
`SSH_KNOWN_HOSTS`, `PUBLISH_HOST`, `PUBLISH_DIR`; y variables `SIGNING_CERT_SHA256`, `APK_BASE_URL`.
El keystore se decodifica en `$RUNNER_TEMP`, `key.properties` se escribe allí y ambos se borran al
final (`if: always()`). No se usa `set -x`; el bloque de secretos usa `::add-mask::` para los derivados.
`known_hosts` va fijado (sin `ssh-keyscan` a ciegas).

**Dev sin configurar**: un primer paso comprueba si faltan los secretos/variables de `development`.
En `push` a `dev` termina en verde con un aviso («omitido: sin configuración»); en lanzamiento manual
falla con mensaje claro (US3.2, US4.2, FR-011).

## R8 — Validación del `ref` manual (FR-009)

**Decisión**: para `prod`, el `ref` indicado debe ser ancestro de `origin/main`
(`git merge-base --is-ancestor`); si no, el proceso falla antes de compilar. Por defecto se usa la
punta de `main`. Para `dev` ocurre lo mismo respecto a `dev`.

## R9 — Versión de Flutter y caché

**Decisión**: fijar en el workflow la versión exacta de Flutter que se usa en local (`flutter --version`
al implementar) con `subosito/flutter-action` y su caché; JDK 17 (el proyecto compila con JVM 17).
**Razón**: compilación reproducible; un cambio de Flutter en el runner no debe romper la publicación.

## R10 — Pruebas del CI

**Decisión**: `app/scripts/tests/test_scripts.sh` ejecuta los scripts con `ssh`, `scp`, `curl` y
`apksigner` simulados y comprueba: versión creciente, firma distinta rechazada, subida cortada deja el
APK anterior, verificación fallida restaura la copia, falta de secretos nombra qué falta sin
imprimirlos. `shellcheck` y `actionlint` validan scripts y YAML. La publicación real de prueba se
hace con `workflow_dispatch` (SC-003, SC-004).

**Descartado**: `flutter test` en el workflow de publicación; añadiría minutos (SC-001) y las pruebas
ya son requisito de cada feature antes de fusionar (principio IX).

## Resumen

| Tema | Decisión |
|---|---|
| Lógica | Scripts compartidos con el flujo manual |
| Disparo | `push` a `main`/`dev` con `app/**` + `workflow_dispatch` |
| Versión | Minutos UTC desde época, vía `--build-number` |
| Firma | Huella SHA-256 contra variable `SIGNING_CERT_SHA256` |
| Subida | `.tmp` + `mv` atómico + copia `.prev` + verificación por huella + retorno |
| Concurrencia | Grupo por entorno, sin cancelar |
| Secretos | Environments `production`/`development`; limpieza al final |
| Manual | Entorno y commit (debe pertenecer a la rama del entorno) |
