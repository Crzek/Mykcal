# Despliegue en producción

Entorno `production`: rama `main`, API en `https://mykcal-bk-api.cruzerick.com`.
Detalle y justificación en `specs/001-acceso-y-despliegue/contracts/dokploy-setup.md`.

## ⚠️ Antes de empezar (importante)

1. **Zitadel ya configurado** (organización `mykcal`, proyecto, app nativa). En la app nativa:
   *Authorization Code* **y Refresh Token** marcados, y **Auth Token Type = JWT**
   (pestaña de tokens). Sin JWT el backend responde 401 a todo.
2. **SMTP** configurado en Zitadel: sin él no llega el correo de verificación del registro.
3. **El backend tiene que estar en la rama que despliega Dokploy.** `main` aún no lo tiene;
   hasta fusionar, apunta la Application a `001-acceso-y-despliegue`.
4. **Copia de seguridad del keystore** (`~/.keystores/mykcal-release.jks` y su contraseña).
   Si se pierde, los usuarios deben desinstalar la app para actualizarla.

## 1. PostgreSQL

Dokploy → proyecto `mykcal` → entorno `production` → *Create Service → Database → PostgreSQL*.

- Versión 16, base `mykcal`, nombre del servicio `mykcal-db`.
- **Sin puerto externo.**
- Copia la *Internal Connection URL*: es el `DATABASE_URL`.

## 2. Application

| Ajuste | Valor |
|---|---|
| Origen | este repositorio, rama `main` (o la de la feature, ver arriba), autodeploy |
| Build Type | Dockerfile |
| Docker File / Context | `backend/Dockerfile` / `backend` |
| Puerto | 8000 |
| Health check | `GET /v1/health` |
| Swarm Update Config | `Order: start-first`, `FailureAction: rollback` |
| Volumen | *Volume mount* `mykcal-apk` → `/data/apk` |
| Dominio | `mykcal-bk-api.cruzerick.com`, puerto 8000, HTTPS (Let's Encrypt) |

### Variables de entorno

Valores de ejemplo y dónde sacar cada una: `backend/.env.example`.

| Variable | Valor |
|---|---|
| `DATABASE_URL` | URL interna del paso 1 (secreta) |
| `OIDC_ISSUER` | `https://mg-zitadel.cruzerick.com` (sin `/` final, con `https`) |
| `OIDC_PROJECT_ID` | `400870782219059203` |
| `ADMIN_SUBJECT` | `400872040560590851` |
| `APP_ENV` | `production` |
| `OFF_USER_AGENT` | opcional; por defecto `Mykcal/0.3 (app privada)`. Open Food Facts pide identificar la app: conviene añadir un contacto |
| `OFF_BASE_URL` | opcional; por defecto `https://world.openfoodfacts.org` (con `https`) |
| `OFF_TIMEOUT_S` | opcional; por defecto 5 (de 1 a 30) |

Si falta una obligatoria, el contenedor no arranca y el log nombra cuál.

## 3. Desplegar y comprobar

Al arrancar, el contenedor aplica las migraciones, carga los alimentos genéricos
(`generic_import_done` o `generic_import_noop` en el log; si falla, la API arranca igual y el log
muestra `generic_import_failed`) y luego levanta la API.

```bash
curl -s  https://mykcal-bk-api.cruzerick.com/v1/health      # {"status":"ok"}
curl -si https://mykcal-bk-api.cruzerick.com/v1/me | head -1 # 401
```

Si la migración falla, el contenedor no arranca y el relevo sigue sirviendo la versión anterior.

## 4. Publicar el APK

Requiere `app/android/key.properties` y `~/.config/mykcal/publish.env` (host y ruta del
volumen para `scp`; fuera del repo).

```bash
app/scripts/build_apk.sh prod     # firma con el keystore local
app/scripts/publish_apk.sh prod   # scp al volumen como mykcal.apk
curl -I https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk   # 200
```

## 5. Primer acceso

1. Instala el APK desde esa URL en el móvil.
2. Inicia sesión con el usuario administrador: entra **sin código** y ocupa la primera plaza.
3. *Invitaciones → Cambiar código* para generar el primer código.
4. Pásalo a las demás personas. Hasta que exista un código vigente, nadie más puede registrarse.

## Checklist final

- [ ] `/v1/health` → 200 y `/v1/me` sin token → 401
- [ ] APK se descarga con `200`
- [ ] Inicio de sesión del administrador y código generado
- [ ] Una segunda persona se registra con el código
- [ ] Cerrar y reabrir la app mantiene la sesión
