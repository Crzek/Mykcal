# Quickstart: validar la publicación automática

Detalles en [contracts/workflow.md](./contracts/workflow.md) y [contracts/scripts.md](./contracts/scripts.md).

## Prerrequisitos (una vez)

1. Crear el entorno de GitHub `production` con los secretos y variables de
   [data-model.md](./data-model.md) (guía: `docs/deploy/publicar-apk.md`).
2. Generar la clave SSH dedicada, autorizarla en el servidor solo para la carpeta del APK y guardar
   `known_hosts`.
3. Anotar la huella actual: `app/scripts/apk_cert_sha256.sh <apk ya publicado>` → `SIGNING_CERT_SHA256`.

## Pruebas automáticas (antes de fusionar)

```bash
shellcheck app/scripts/*.sh
actionlint .github/workflows/publish-apk.yml
bash app/scripts/tests/test_scripts.sh
```

## Escenarios manuales

### V1 — Publicación al fusionar (US1, SC-001/003)
1. Fusiona en `main` un cambio visible en `app/`.
2. En *Actions* aparece la ejecución; termina en < 15 min.
3. Descarga `https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk`, instálalo sobre el anterior
   (sin desinstalar) y comprueba el cambio y que la sesión se mantiene.
4. Repite con otro merge: el `versionCode` (Ajustes → Info de la app o `aapt dump badging`) es mayor.

### V2 — Merge sin cambios en la app (US1.4)
Fusiona un cambio solo de `backend/` o docs: no hay ejecución de publicación.

### V3 — Fallos (US2, SC-002)
1. Fuerza fallo de compilación (error de sintaxis en una rama de prueba lanzada a mano): enlace intacto.
2. Con `PUBLISH_HOST` erróneo: falla la subida, enlace intacto.
3. Con una huella esperada distinta: falla antes de subir (FR-007).
4. Comprueba el correo de GitHub por la ejecución fallida.

### V4 — Manual (US3, FR-009)
1. *Run workflow* → `prod`, sin `ref`: se publica la punta de `main`.
2. Con un `ref` de una rama de feature: falla antes de compilar.
3. Con `dev` sin configurar: fallo claro; con un `push` a `dev`: omitido en verde (US4.2).

### V5 — Secretos (SC-004)
Revisa los registros de 3 ejecuciones: no aparecen contraseñas, claves ni el keystore.

### V6 — Flujo manual (FR-013)
`app/scripts/build_apk.sh prod && app/scripts/publish_apk.sh prod` publica igual y con la misma
verificación.
