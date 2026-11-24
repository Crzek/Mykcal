# Contrato: despliegue en Dokploy

Proyecto de Dokploy `mykcal` con dos entornos idénticos salvo por los valores de la tabla.
Decisiones en research R9 y R10. El esquema se copia de `../ligon/docs/deploy.md`.

| | `production` | `development` |
|---|---|---|
| Rama (autodeploy) | `main` | `dev` |
| Dominio | `mykcal-bk-api.cruzerick.com` | `mykcal-bk-dev-api.cruzerick.com` |
| PostgreSQL | `mykcal-db` | `mykcal-db-dev` |

## 1. PostgreSQL (por entorno)

- *Create Service → Database → PostgreSQL*: versión 16, base `mykcal`, usuario y contraseña
  generados por Dokploy.
- **Sin puerto externo**.
- *Internal Connection URL* → `DATABASE_URL` de la aplicación. La conexión va sin TLS porque el
  tráfico es interno y el host es un nombre de servicio sin puntos.
- Sin copias de seguridad (decisión aceptada en la constitución).

## 2. Application (por entorno)

| Ajuste | Valor |
|---|---|
| Origen | este repositorio, rama de la tabla, autodeploy activado |
| Build Type | Dockerfile |
| Docker File / Context | `backend/Dockerfile` / `backend` |
| Puerto interno | 8000 |
| Health check | `GET /v1/health` |
| Update Config (Swarm) | `Order: start-first`, `FailureAction: rollback` |
| Volumen | *Volume mount* `mykcal-apk[-dev]` → `/data/apk` |
| Dominio | el de la tabla, HTTPS con Let's Encrypt, puerto 8000 |

### Variables de entorno

| Variable | Obligatoria | Secreto | Valor |
|---|---|---|---|
| `DATABASE_URL` | sí | sí | URL interna del paso 1 |
| `OIDC_ISSUER` | sí | no | `https://mg-zitadel.cruzerick.com` (sin `/` final; con `http://` no arranca) |
| `OIDC_PROJECT_ID` | sí | no | ID del proyecto `mykcal` |
| `ADMIN_SUBJECT` | sí | no | User ID de Zitadel de Erick (zitadel-setup §3) |
| `APP_ENV` | sí | no | `production` / `development` (solo para los logs) |
| `APK_DIR` | no | no | por defecto `/data/apk` |
| `MIGRATION_TIMEOUT_S` | no | no | por defecto 120 |
| `OFF_USER_AGENT` | no | no | por defecto `Mykcal/0.3 (app privada)`; Open Food Facts pide identificar la app, conviene añadir un contacto |
| `OFF_BASE_URL` | no | no | por defecto `https://world.openfoodfacts.org` (debe empezar por `https://`) |
| `OFF_TIMEOUT_S` | no | no | por defecto 5 (de 1 a 30) |

Si falta una variable obligatoria, el contenedor no arranca y el log la nombra sin mostrar su
valor.

Al arrancar, tras la migración, el contenedor carga los alimentos genéricos
(`python -m mykcal.foods.load_generic`): `generic_import_done` la primera vez y tras cada cambio de
la semilla, `generic_import_noop` si no hay cambios. Si falla, la API arranca igualmente y el log
muestra `generic_import_failed`.

### Arranque

`docker-entrypoint.sh` → `python -m mykcal.migrate` (Alembic, con bloqueo consultivo, que
nunca hace downgrade por su cuenta) → `uvicorn mykcal.main:create_app --factory --host 0.0.0.0 --port 8000`. Si
la migración falla, el contenedor no arranca y, con el relevo, sigue sirviendo la versión
anterior.

## 3. Publicar el APK

1. `app/scripts/build_apk.sh prod` (o `dev`) compila
   `build/app/outputs/flutter-apk/app-<sabor>-release.apk` firmado con el keystore local.
2. `app/scripts/publish_apk.sh prod` (o `dev`) lo copia con `scp` como `mykcal.apk` al
   directorio del volumen en el servidor. El host y la ruta van en `~/.config/mykcal/publish.env`,
   fuera del repositorio.
3. Comprobación: `curl -I https://<dominio>/descargar/mykcal.apk` → `200` con
   `application/vnd.android.package-archive`.

## 4. Comprobación antes de dar el entorno por listo

- [ ] `GET /v1/health` → 200.
- [ ] `GET /v1/me` sin token → 401.
- [ ] El primer alta es la del administrador (sin código) y genera el código desde la app.
- [ ] El APK se descarga desde el móvil.
