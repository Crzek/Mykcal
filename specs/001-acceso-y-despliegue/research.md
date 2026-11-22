# Research: 001 — Acceso por invitación y sesión

Decisiones técnicas de la feature. Datos de infraestructura aportados por Erick el 2026-11-22.
Patrón de referencia: Ligón (`../ligon`, feature 005 `zitadel-auth` y `docs/deploy.md`).

## Datos de entorno (fijos)

| Dato | Producción (`main`) | Desarrollo (`dev`) |
|---|---|---|
| API | `https://mykcal-bk-api.cruzerick.com` | `https://mykcal-bk-dev-api.cruzerick.com` |
| Zitadel (`OIDC_ISSUER`) | `https://mg-zitadel.cruzerick.com` | igual |
| Proyecto Zitadel | `mykcal` (uno solo) | igual |
| Aplicación nativa | `mykcal-android` | `mykcal-android-dev` |
| `applicationId` Android | `com.cruzerick.mykcal` | `com.cruzerick.mykcal.dev` |
| Base de datos | PostgreSQL propio de prod | PostgreSQL propio de dev |
| APK | `https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk` | `https://mykcal-bk-dev-api.cruzerick.com/descargar/mykcal.apk` |

---

## R1. Registro con código: autorregistro en Zitadel + alta en Mykcal (opción A)

**Decisión**: la persona crea su usuario en Zitadel con la página de registro propia de Zitadel.
Después, la app llama a `GET /v1/me`. Si el backend no tiene cuenta para ese `sub`, responde
`ACCOUNT_NOT_REGISTERED` y la app muestra la pantalla del código de invitación.
`POST /v1/registration` crea la cuenta de Mykcal solo si el código es el vigente y hay menos de
50 cuentas activas.

**Rationale**: Mykcal no guarda credenciales de administración de Zitadel ni llama a su
Management API. La puerta de entrada real (FR-001) es la cuenta de Mykcal: sin ella, cualquier
endpoint distinto de `/v1/me` y `/v1/registration` responde `ACCOUNT_NOT_REGISTERED`.

**Consecuencia aceptada**: alguien sin código puede crear un usuario en Zitadel, pero no puede
usar Mykcal. Ese usuario de Zitadel no tiene acceso a nada más, porque la organización es
propia (R2).

**Alternativas**: creación del usuario desde el backend con la Management API (opción B). Se
rechaza porque necesita una service account con permisos de escritura y más código. Erick
eligió A.

## R2. Organización de Zitadel propia: `mykcal`

**Decisión**: se crea una organización `mykcal` en la instancia `mg-zitadel.cruzerick.com`. El
proyecto `mykcal` vive en ella. La app pide el scope `urn:zitadel:iam:org:id:<OIDC_ORG_ID>`, así
que la página de inicio de sesión y la de registro aplican la política de esta organización, y
los usuarios nuevos se crean en ella.

**Rationale**: la organización que usa Ligón tiene *Register allowed = no* y *Force MFA = sí*,
porque así lo exige la constitución de Ligón. Activar el registro allí abriría el autorregistro
en Ligón. Con una organización separada, cada política es independiente.

**Política de inicio de sesión de `mykcal`**: Register allowed **sí**, Username/password **sí**,
Passkeys **sí**, Force MFA **no** (opcional para el usuario), External IdP **no**.

**Consecuencia**: Erick necesita un usuario propio dentro de la organización `mykcal`. Su usuario
de Ligón está en otra organización y no le sirve. El `sub` de ese usuario nuevo es el valor de
`ADMIN_SUBJECT`.

**Pendiente de comprobar al configurar**: la instancia tiene que tener **SMTP** configurado para
enviar el correo de verificación del registro. Si no lo tiene, el registro se queda a medias. Es
un paso de `contracts/zitadel-setup.md`.

## R3. Una aplicación nativa por entorno, en un solo proyecto

**Decisión**: proyecto `mykcal` con dos aplicaciones *Native* (PKCE, sin secreto, *Auth Token
Type* = JWT). Los redirects son `com.cruzerick.mykcal:/oauth2redirect` y
`com.cruzerick.mykcal.dev:/oauth2redirect`, con su `:/logout` para el cierre de sesión.
*Check authorization on Authentication* = **no**: los usuarios autorregistrados no tienen grants
del proyecto, y la autorización la decide la cuenta de Mykcal.

**Rationale**: Erick lo pidió así (dev apenas se usará). Los usuarios de Zitadel se comparten
entre entornos. Los **datos** quedan separados, como pide FR-019, porque cada entorno tiene su
propia base: una persona registrada en prod no tiene cuenta en dev hasta que se registre allí
con el código de dev.

## R4. Validación del token: JWT contra el JWKS, sin introspección

**Decisión**: el backend valida en local la firma RS256 contra el JWKS de
`OIDC_ISSUER/.well-known/openid-configuration`. Las claves quedan en memoria y se vuelven a
descargar cuando llega un `kid` desconocido, como mucho una vez cada 5 minutos. También
comprueba `iss` = `OIDC_ISSUER`, `exp` y `nbf` con 30 s de margen, y que `aud` contenga
`OIDC_PROJECT_ID`. Para eso la app pide el scope `urn:zitadel:iam:org:project:id:<id>:aud`. La
identidad es `sub` (FR-010).

**Rationale**: es lo que manda la constitución (principio V). Ligón añadió introspección para
detectar revocaciones en Zitadel. Aquí no hace falta, porque el estado que cuenta
(activa/desactivada) está en la base de Mykcal y se consulta en cada petición. Usar solo el JWKS
evita guardar un secreto de cliente API (principio VII).

**Riesgo aceptado**: si se revoca una sesión en Zitadel, el access token sigue valiendo hasta
que caduca, como mucho 15 minutos.

**Zitadel caído**: si no hay JWKS en memoria y no se puede descargar → `503 AUTH_UNAVAILABLE`.

**Librerías**: `pyjwt[crypto]` y `httpx`, igual que en Ligón.

## R5. Nombre visible

**Decisión**: al registrarse, el backend llama a `userinfo_endpoint` con el mismo bearer token
(scopes `openid profile email`) y guarda `name` (o `preferred_username` si falta) como
`display_name`. `GET /v1/me` vuelve a llamar a `userinfo` si han pasado más de 24 h desde la
última sincronización, para recoger cambios de nombre. Si `userinfo` falla, se mantiene el
nombre guardado. El email **no** se guarda (minimización, principio IV).

**Alternativas**: leer `name` del access token. Se rechaza porque el JWT de acceso de Zitadel no
lleva claims de perfil por defecto.

## R6. Administrador por `ADMIN_SUBJECT`

**Decisión**: es administrador quien tenga `sub == ADMIN_SUBJECT`, una variable de entorno de
Dokploy por entorno. No se guarda en la base: `is_admin` se calcula en cada petición. Es
obligatoria y el backend no arranca sin ella.

**Arranque inicial**: el administrador puede registrarse **sin código**, porque al principio no
existe ninguno, y ocupa una de las 50 plazas. Desde la app genera el primer código. Mientras no
haya código vigente, nadie más puede registrarse.

## R7. Código de invitación: generación, comparación y concurrencia

- **Generación**: la genera el servidor con `secrets.choice`. Son 8 caracteres del alfabeto
  Crockford sin ambigüedades (`0-9 A-Z` sin `I L O U`), unos 40 bits. El administrador no lo
  escribe a mano.
- **Normalización**: `strip()` y mayúsculas antes de comparar y de guardar. También se quitan
  los espacios y guiones intermedios, porque la app muestra el código como `ABCD-EFGH`.
- **Comparación**: `hmac.compare_digest` con el código vigente normalizado.
- **Un solo vigente** (FR-003): columna `is_current` con índice único parcial `WHERE is_current`.
  Al rotar, en la misma transacción se pone `is_current=false` y `superseded_at` en el anterior,
  y se inserta el nuevo.
- **Concurrencia** (casos límite: plaza 50 y cambio de código durante un alta): el alta y la
  rotación toman `pg_advisory_xact_lock(<constante>)`. Dentro del bloqueo, el alta vuelve a leer
  el código vigente y cuenta las cuentas activas. Así dos altas simultáneas no pueden ocupar la
  misma plaza y ningún alta usa un código ya sustituido.
- **Texto en claro**: el código se guarda en claro porque el administrador tiene que poder
  consultarlo (US4). No es una credencial: sin un usuario de Zitadel no sirve para nada.

## R8. Espera creciente tras intentos fallidos (FR-013)

**Decisión**: el límite va por `sub`. Con la opción A, quien intenta registrarse ya tiene sesión
en Zitadel, y un `sub` equivale a una persona y su dispositivo. Una tabla
`registration_throttle` guarda los fallos consecutivos:
- Los fallos 1 a 3 no tienen espera.
- A partir del 4.º, la espera es `min(30 s × 2^(n−4), 1 h)`.
- Mientras dura la espera → `429 TOO_MANY_ATTEMPTS` con `Retry-After`, sin evaluar el código.
- Un alta correcta borra la fila.
- La fila se lee con `FOR UPDATE`, para que dos peticiones simultáneas no se salten la cuenta.

**Rationale**: sin Redis ni caché externa (principio VII), y funciona aunque se reinicie el
contenedor. La app desactiva el botón durante `Retry-After` y muestra la cuenta atrás.

- **Límite global** (contra quien crea usuarios nuevos en Zitadel para tener más intentos libres):
  tabla `registration_failure` con cada fallo. Si hay **20 o más fallos en los últimos 10 min**
  entre todas las identidades, las altas se rechazan con `429 TOO_MANY_ATTEMPTS` y `Retry-After`
  hasta que pasen 10 min desde el último fallo. Se evalúa dentro del mismo bloqueo consultivo de
  R7. Las filas de más de 1 h se borran en cada intento. El administrador no registra fallos.
- Con ~40 bits de código y como mucho 2 intentos por minuto de media, adivinarlo es inviable.

**Alternativa**: limitar por IP con Traefik. No sustituye al límite global (la IP se cambia con
facilidad) y castiga a quien comparte red; queda como mejora opcional.

## R9. Distribución del APK desde el propio backend

**Decisión**: `GET /descargar/mykcal.apk` (público) sirve el fichero de `APK_DIR`
(`/data/apk/mykcal.apk`), un volumen persistente de Dokploy montado en la aplicación. Las
cabeceras son `Content-Type: application/vnd.android.package-archive`,
`Content-Disposition: attachment; filename="mykcal.apk"` y `Cache-Control: no-cache`. Si no hay
APK → `404`.

**Publicar una versión**: Erick compila en su equipo con
`app/scripts/build_apk.sh <prod|dev>`, que firma con su keystore de release local y usa
`--dart-define-from-file`. Después sube el fichero con `app/scripts/publish_apk.sh <prod|dev>`,
que hace `scp` al directorio del volumen en el servidor de Dokploy. La ruta del host va en una
variable local del script, no en el repositorio.

**Rationale**: cumple «se descarga desde una URL de este proyecto» sin compilar Flutter dentro
de la imagen del backend. Eso haría el build muy lento y obligaría a meter el keystore en los
build args de Dokploy.

**Alternativas**:
- Compilación multi-etapa en el Dockerfile: se rechaza por tiempo de build y por los secretos.
- Endpoint de subida para el administrador: se rechaza porque es más código y más superficie de
  ataque.
- GitHub Releases: se rechaza porque Erick quiere la URL del proyecto.

**Firma**: un único keystore de release (`~/.keystores/mykcal-release.jks`, **fuera del
repositorio**) para los dos sabores. Si se pierde, los usuarios tendrán que desinstalar para
actualizar.

**Excepción a «todo endpoint exige identidad»**: ver Complexity Tracking en plan.md.

## R10. Despliegue en Dokploy

**Decisión**: proyecto de Dokploy `mykcal` con dos entornos, `production` y `development`. Cada
uno tiene:
- *Database → PostgreSQL 16* propio, sin puerto externo. La base se llama `mykcal`.
- *Application*: origen el repositorio, rama `main` o `dev` con autodeploy, *Build Type*
  Dockerfile (`backend/Dockerfile`, contexto `backend`), puerto 8000, health check
  `GET /v1/health`, relevo `start-first` + `rollback`.
- Volumen `/data/apk` y dominio HTTPS con Let's Encrypt (R9).
- Migraciones Alembic al arrancar (`docker-entrypoint.sh` → `python -m mykcal.migrate` →
  `uvicorn`), con bloqueo consultivo, igual que en Ligón.

**Desviación de la constitución**: la constitución dice «Docker Compose en Dokploy». Erick ha
pedido el esquema de Ligón (Application + servicio PostgreSQL de Dokploy). Ver Complexity
Tracking. En local sí se usa `backend/docker-compose.dev.yml` para PostgreSQL.

**Copias de seguridad**: no hay, por decisión de Erick y según la constitución.

## R11. Sesión en la app (patrón de Ligón)

**Decisión**:
- Inicio de sesión con `flutter_appauth`: PKCE, navegador del sistema, scopes
  `openid profile email offline_access`, más el scope de organización (R2) y el de audiencia
  (R4).
- Los tokens se guardan en `flutter_secure_storage`.
- Renovación transparente con el refresh token. Zitadel lo rota; se guarda siempre el último. Si
  hay varias renovaciones simultáneas, comparten una sola llamada.
- Un `401` del API provoca una renovación y un reintento. Si la renovación falla, la app lleva
  al inicio de sesión **sin descartar** el estado de los formularios (FR-008 y caso límite).
- Para cerrar sesión: revocar el refresh token y llamar a `end_session` con un plazo máximo. Los
  tokens locales se borran siempre.

**Duración**: son los ajustes de la instancia, que comparte con Ligón: access token 15 min,
refresh 7 días sin uso y 30 días en total. Un usuario activo vuelve a introducir credenciales
como mucho cada 30 días. SC-006 se cumple «mientras la sesión sea válida».

## R12. Sin conexión y errores (FR-015)

**Decisión**: cliente `dio` con plazos de 10 s. Los errores de red se traducen a un
`NetworkFailure` que la UI muestra con el banner «Necesitas conexión a Internet» y un botón
«Reintentar». Los campos de texto guardan su valor en un `Notifier` de Riverpod que no se
descarta al cambiar de pantalla. Un `5xx` o un timeout se muestran como «El servidor no
responde» con reintento.

## R13. Registro de errores (FR-014, principio X)

**Decisión**: `structlog` con salida JSON y **lista blanca** de campos: `event`, `path`,
`method`, `status`, `error_code`, `error_class`, `auth_reason`, `duration_ms`, `request_id` y
`user_id`, que es el UUID interno y no el `sub`. Un manejador global registra todas las
excepciones no controladas como `unhandled_error` con `error_class`, sin el mensaje. La cabecera
`Authorization` y los cuerpos no se registran nunca. Hay una prueba que comprueba que un token no
aparece en los logs.

## R14. Accesibilidad e idioma (FR-016, FR-017)

**Decisión**:
- `flutter_localizations` + ARB (`lib/l10n/app_es.arb`) con `es` como único locale.
- `ThemeMode.system`, con tema claro y oscuro desde un `ColorScheme.fromSeed` comprobado a
  contraste AA.
- Sin tamaños de texto fijos que ignoren `MediaQuery.textScaler`.
- `Semantics`/`tooltip` en todos los controles.
- En las pruebas de widgets: `meetsGuideline(textContrastGuideline)`,
  `labeledTapTargetGuideline` y `androidTapTargetGuideline` en cada pantalla (SC-007).

## R15. Pruebas sin servicios reales (principio VI)

**Decisión**:
- **Backend**: `pytest` + `pytest-asyncio`, PostgreSQL con `testcontainers` y Zitadel simulado
  (un par de claves RSA generado en la prueba, JWKS servido con `httpx.MockTransport` y
  `userinfo` simulado).
- **Pruebas `privacy`/`isolation` obligatorias**: recorren `app.routes` y comprueban que toda
  ruta, salvo las públicas de la lista explícita, rechaza sin token, con token caducado, con
  firma ajena, con `aud` ajena y con cuenta desactivada (SC-003). También comprueban que el
  administrador no recibe datos de otros usuarios.
- Pruebas de concurrencia de la plaza 50 y de la rotación durante un alta.
- **Contrato**: `contracts/openapi.yaml` validado contra las respuestas.
- **App**: `flutter_test` + `mocktail`, con `AuthService` y el cliente API simulados. Las pruebas
  de integración en el emulador son manuales (principio IX).

## R16. Versiones

- **Backend**: Python 3.12, FastAPI ≥ 0.115, SQLAlchemy 2 async + asyncpg, Alembic,
  pydantic-settings, structlog, httpx, pyjwt[crypto]. Gestor: `uv`.
- **App**: Flutter ≥ 3.32 (Dart ≥ 3.5), flutter_riverpod, dio, flutter_appauth,
  flutter_secure_storage y mocktail.
- `minSdk` 24.

Antes de implementar se consultan las versiones exactas con Context7.
