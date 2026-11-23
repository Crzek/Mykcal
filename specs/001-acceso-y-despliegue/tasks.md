---

description: "Tareas de la feature 001 — Acceso por invitación y sesión"
---

# Tasks: Acceso por invitación y sesión

**Input**: `specs/001-acceso-y-despliegue/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Prerequisites**: plan.md, spec.md. Antes de la Fase 2 de backend, Erick completa `contracts/zitadel-setup.md` (organización `mykcal`, proyecto, apps, SMTP, usuario admin) para tener `OIDC_ORG_ID`, `OIDC_PROJECT_ID`, `OIDC_CLIENT_ID` (prod y dev) y `ADMIN_SUBJECT`.

**Tests**: SÍ se incluyen. La constitución (principios V y VI) exige pruebas automáticas de privacidad y aislamiento, sin servicios reales (Zitadel simulado con claves RSA de prueba, PostgreSQL con testcontainers). Escribir cada prueba antes de su implementación y comprobar que falla.

**Organization**: por historia de usuario. Orden de fases elegido por dependencias técnicas (las cinco historias son P1 salvo US4 = P2): US3 → US2 → US1 → US4 → US5.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: paralelizable (ficheros distintos, sin dependencias pendientes)
- **[Story]**: US1…US5, solo en las fases de historia
- Rutas relativas a la raíz del repositorio. Backend: `backend/src/mykcal/`; app: `app/lib/`

## Path Conventions

Monorepo móvil + API: `backend/` (FastAPI, paquete `mykcal`) y `app/` (Flutter, sabores `prod`/`dev`).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: esqueleto del monorepo y herramientas

- [X] T001 Crear la estructura `backend/src/mykcal/{core,accounts,invitations,distribution}/`, `backend/tests/{contract,privacy,integration,unit}/` y `backend/alembic/versions/` con sus `__init__.py`
- [X] T002 Crear `backend/pyproject.toml` (Python >=3.12,<3.13; fastapi>=0.115, uvicorn[standard], pydantic>=2.7, pydantic-settings, sqlalchemy[asyncio]>=2.0, asyncpg, alembic, structlog, httpx, pyjwt[crypto]; dev: pytest, pytest-asyncio, testcontainers[postgres], openapi-core, pyyaml, ruff; `asyncio_mode="auto"`; marcadores `privacy` e `isolation`; ruff line-length 100) y generar `backend/uv.lock` con `uv lock`. Consultar versiones con Context7
- [X] T003 [P] Crear `backend/.env.example` (DATABASE_URL, OIDC_ISSUER, OIDC_PROJECT_ID, ADMIN_SUBJECT, APP_ENV, APK_DIR, MIGRATION_TIMEOUT_S; sin valores reales) y `backend/docker-compose.dev.yml` (PostgreSQL 16, base `mykcal`, solo en 127.0.0.1)
- [X] T004 [P] Crear la app Flutter en `app/` con `flutter create --org com.cruzerick --project-name mykcal --platforms android app`; editar `app/pubspec.yaml` con flutter_riverpod, dio, flutter_appauth, flutter_secure_storage, flutter_localizations, intl; dev: flutter_test, mocktail, flutter_lints (consultar versiones con Context7)
- [X] T005 Configurar los sabores Android en `app/android/app/build.gradle`: `prod` con `applicationId com.cruzerick.mykcal` y `dev` con `applicationIdSuffix ".dev"`; `minSdk 24`; `manifestPlaceholders.appAuthRedirectScheme` = `com.cruzerick.mykcal` / `com.cruzerick.mykcal.dev`; firma de release leyendo `~/.keystores/mykcal-release.jks` desde `key.properties` fuera del repositorio
- [X] T006 [P] Crear `app/config/dev.json` y `app/config/prod.json` con `OIDC_ISSUER=https://mg-zitadel.cruzerick.com`, `OIDC_ORG_ID`, `OIDC_PROJECT_ID`, `OIDC_CLIENT_ID` y `API_BASE_URL` (`https://mykcal-bk-dev-api.cruzerick.com` / `https://mykcal-bk-api.cruzerick.com`). Ninguno es secreto
- [X] T007 [P] Configurar `app/l10n.yaml` y `app/lib/l10n/app_es.arb` (único locale `es`, `generate: true` en pubspec) y `app/analysis_options.yaml` con flutter_lints
- [X] T008 [P] Añadir `.gitignore` en la raíz con `.env`, `key.properties`, `*.jks`, `*.keystore`, `.venv/`, `build/`, `.dart_tool/`, `app/config/*.local.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: núcleo de configuración, base de datos, errores, logs y validación del JWT que necesitan todas las historias

**⚠️ CRITICAL**: ninguna historia puede empezar hasta terminar esta fase

### Backend

- [X] T009 Implementar `backend/src/mykcal/config.py`: `Settings` (pydantic-settings) con `DATABASE_URL` (convierte el esquema a `postgresql+asyncpg://`; solo acepta URL sin TLS si el host es local, IP privada o nombre de servicio sin puntos; si no, exige `?ssl=require`), `OIDC_ISSUER` (`https://`, sin `/` final; con `http://` no arranca), `OIDC_PROJECT_ID`, `ADMIN_SUBJECT`, `APP_ENV` (`production`|`development`), `APK_DIR` (por defecto `/data/apk`), `MIGRATION_TIMEOUT_S` (por defecto 120) y `MAX_ACTIVE_ACCOUNTS = 50`. Si falta una obligatoria, falla al arrancar nombrando la variable sin mostrar valores
- [X] T010 [P] Implementar `backend/src/mykcal/logging.py`: structlog en JSON con lista blanca de campos (`event`, `path`, `method`, `status`, `error_code`, `error_class`, `auth_reason`, `duration_ms`, `request_id`, `user_id`); nunca registrar `Authorization`, cuerpos ni `sub` (research R13)
- [X] T011 [P] Implementar `backend/src/mykcal/core/errors.py`: `ErrorBody` (`code`, `message`, `retry_after_s` opcional), enum de códigos de `contracts/openapi.yaml` (UNAUTHORIZED, AUTH_UNAVAILABLE, ACCOUNT_NOT_REGISTERED, ACCOUNT_DISABLED, FORBIDDEN, ALREADY_REGISTERED, INVITATION_INVALID, NO_SEATS, TOO_MANY_ATTEMPTS, VALIDATION_ERROR, INTERNAL_ERROR) y `ApiError(status, code, message, headers)`
- [X] T012 Implementar `backend/src/mykcal/db.py`: engine y sesión async de SQLAlchemy 2, con `Base` declarativa y la dependencia `get_session`
- [X] T013 Crear la migración `backend/alembic.ini`, `backend/alembic/env.py` (async) y `backend/alembic/versions/0001_access.py` con las tres tablas de `data-model.md`:
  - `user_account`: `id uuid PK default gen_random_uuid()`, `subject text NOT NULL UNIQUE`, `display_name text NOT NULL` (1–200 caracteres), `display_name_synced_at timestamptz NOT NULL`, `status text NOT NULL CHECK (status IN ('active','disabled'))` por defecto `active`, `created_at timestamptz NOT NULL`, `disabled_at timestamptz NULL` con CHECK «no nulo ⇔ status='disabled'»; índice parcial `ix_user_account_active WHERE status='active'`
  - `invitation_code`: `id uuid PK`, `code text NOT NULL UNIQUE` (`^[0-9A-HJKMNP-TV-Z]{8}$`), `is_current boolean NOT NULL` con índice único parcial `WHERE is_current`, `created_at timestamptz NOT NULL`, `created_by uuid NOT NULL FK → user_account.id`, `superseded_at timestamptz NULL` con CHECK «no nulo ⇔ is_current=false»
  - `registration_throttle`: `subject text PK`, `consecutive_failures integer NOT NULL` (≥ 1), `last_failure_at timestamptz NOT NULL`, `blocked_until timestamptz NULL`
  - `registration_failure`: `id bigserial PK`, `failed_at timestamptz NOT NULL` con índice `ix_registration_failure_failed_at` (solo el instante; sin `sub` ni código)
- [X] T014 [P] Implementar `get_account_by_subject(session, subject)` en `backend/src/mykcal/accounts/repository.py` y los modelos SQLAlchemy `backend/src/mykcal/accounts/models.py` (`UserAccount`, `RegistrationThrottle`, `RegistrationFailure`) y `backend/src/mykcal/invitations/models.py` (`InvitationCode`), con los mismos tipos y restricciones que T013 (la función de consulta la usa T017)
- [X] T015 Implementar `backend/src/mykcal/migrate.py` (Alembic con `pg_advisory_lock`, plazo `MIGRATION_TIMEOUT_S`, eventos `migrate_noop`/`migrate_start`/`migrate_done`/`migrate_failed` con `error_class` y `sqlstate`, sin mensaje de la base; no hace downgrade; si la base es más nueva, `migrate_db_ahead` y arranca) y `backend/docker-entrypoint.sh` (migra y después `uvicorn mykcal.main:create_app --factory --host 0.0.0.0 --port 8000`; `RUN_MIGRATIONS=0` solo para emergencias)
- [X] T016 Implementar `backend/src/mykcal/core/auth.py`: descarga de `OIDC_ISSUER/.well-known/openid-configuration` y JWKS con `httpx` (plazo 5 s); caché en memoria con recarga ante un `kid` desconocido como mucho cada 5 min; validación RS256 con pyjwt de firma, `iss`, `exp`, `nbf` (margen 30 s) y `aud` ∋ `OIDC_PROJECT_ID`; `Principal(subject, account, is_admin)` con `is_admin = subject == ADMIN_SUBJECT`; sin JWKS en memoria y Zitadel caído → `503 AUTH_UNAVAILABLE`; rechazos → `401 UNAUTHORIZED` con `WWW-Authenticate: Bearer error="invalid_token"` y motivo solo en el log como `auth_reason`
- [X] T017 Añadir en `backend/src/mykcal/core/auth.py` las dependencias `get_principal` (solo token válido), `require_registered` (404/403 `ACCOUNT_NOT_REGISTERED` según la tabla de reglas de acceso de data-model.md), `require_active_account` (`ACCOUNT_DISABLED` si está desactivada; es la dependencia por defecto) y `require_admin` (`FORBIDDEN` si no es administrador)
- [X] T018 Implementar `backend/src/mykcal/main.py`: app FastAPI, manejadores de `ApiError` y de excepciones no controladas (registra `unhandled_error` con `error_class`, sin mensaje, y responde `500 INTERNAL_ERROR`), errores de validación → `400 VALIDATION_ERROR`, middleware de `request_id` y registro de acceso sin cabeceras, y `GET /v1/health` público (comprueba la base; 503 si falla)
- [X] T019 Crear `backend/Dockerfile` (Python 3.12 slim, `uv sync --frozen --no-dev`, usuario sin privilegios, `EXPOSE 8000`, `CMD` de uvicorn, entrypoint de T015)

### Pruebas base del backend

- [X] T020 Implementar `backend/tests/conftest.py`: PostgreSQL con testcontainers y migraciones aplicadas; par de claves RSA generado en la prueba; JWKS y `userinfo` servidos con `httpx.MockTransport`; helper `make_token(sub, aud, exp, kid, ...)`; cliente de pruebas; ajustes de prueba con `ADMIN_SUBJECT` conocido
- [X] T021 [P] Test unitario de `config.py` en `backend/tests/unit/test_config.py`: falta de variable obligatoria, `OIDC_ISSUER` con `http://` o `/` final, `DATABASE_URL` con host público sin `ssl=require`
- [X] T022 [P] Test de `core/auth.py` en `backend/tests/integration/test_auth_core.py`: token válido; caducado; `nbf` futuro; firma de otra clave; `iss` ajeno; `aud` ajeno; sin `Bearer`; `kid` desconocido provoca una única recarga del JWKS (y no más de una cada 5 min); JWKS no disponible → 503
- [X] T023 [P] Test del logging en `backend/tests/privacy/test_logs_no_secrets.py` (`@pytest.mark.privacy`): tras peticiones con token válido, inválido y con un 500 forzado, ni el token, ni el `sub`, ni la cabecera `Authorization` aparecen en los logs capturados, y el 500 queda registrado como `unhandled_error`; una caída de la base de datos en una ruta real también queda registrada (FR-014)

### App

- [X] T024 [P] Crear `app/lib/core/theme/app_theme.dart` (tema claro y oscuro con `ColorScheme.fromSeed` comprobado a contraste AA, `ThemeMode.system`) y `app/lib/main.dart` con `ProviderScope`, localizaciones `es` y `MaterialApp` sin tamaños de texto fijos que ignoren `MediaQuery.textScaler`
- [X] T025 [P] Implementar `app/lib/core/api/api_client.dart` (dio, plazos de 10 s, base `API_BASE_URL` de `--dart-define-from-file`), `api_errors.dart` (`ApiFailure` con el `code` del API, `NetworkFailure`, `ServerFailure`) y el interceptor que añade `Authorization: Bearer` (la renovación ante 401 se completa en T032)
- [X] T026 [P] Escribir en `app/lib/l10n/app_es.arb` los textos de `contracts/ui-flows.md` (pantallas, mensajes por código de error y banner de conexión) y generar las localizaciones
- [X] T027 [P] Crear `app/test/helpers/a11y.dart` con un helper `expectAccessible(tester)` que ejecuta `meetsGuideline(textContrastGuideline)`, `labeledTapTargetGuideline` y `androidTapTargetGuideline`, y fakes con mocktail de `AuthService` y del cliente API

**Checkpoint**: backend arranca con `/v1/health`, la validación del JWT está probada y la app compila con tema y cliente API.

---

## Phase 3: User Story 3 - Toda función exige identidad (Priority: P1) 🎯 MVP

**Goal**: toda petición sin identidad válida, caducada o de una cuenta desactivada se rechaza, y `GET /v1/me` devuelve identificador, nombre visible, si es administrador y estado.

**Independent Test**: llamar al servidor sin identidad, con identidad caducada, con identidad de una cuenta desactivada y con identidad válida; solo la última obtiene sus datos (spec US3).

### Tests for User Story 3 ⚠️ (escribir antes y comprobar que fallan)

- [X] T028 [P] [US3] Test de contrato de `/v1/me` y `/v1/health` en `backend/tests/contract/test_me_contract.py` validando respuestas contra `specs/001-acceso-y-despliegue/contracts/openapi.yaml` (con openapi-core)
- [X] T029 [P] [US3] Prueba `privacy` en `backend/tests/privacy/test_all_routes_require_identity.py` (`@pytest.mark.privacy`): recorre `app.routes`; solo `GET /v1/health` y `GET /descargar/mykcal.apk` están en la lista pública explícita; el resto rechaza con 401 sin token, con token caducado, con firma ajena y con `aud` ajena (SC-003)
- [X] T030 [P] [US3] Prueba `privacy` en `backend/tests/privacy/test_disabled_account.py` (`@pytest.mark.privacy`): con cuenta `disabled`, `GET /v1/me` devuelve 200 con `status: disabled` y toda otra ruta responde 403 `ACCOUNT_DISABLED`; sin cuenta de Mykcal, `GET /v1/me` da 404 `ACCOUNT_NOT_REGISTERED` y el resto 403
- [X] T031 [P] [US3] Test de integración en `backend/tests/integration/test_me_sync_name.py`: `GET /v1/me` vuelve a llamar a `userinfo` si pasaron más de 24 h desde `display_name_synced_at`, conserva el nombre guardado si `userinfo` falla y nunca guarda el email

### Implementation for User Story 3

- [X] T032 [P] [US3] Implementar `backend/src/mykcal/core/userinfo.py`: llama a `userinfo_endpoint` con el mismo bearer (plazo 5 s), devuelve `name` o, si falta, `preferred_username`, recortado a 1–200 caracteres; no devuelve el email
- [X] T033 [US3] Implementar `backend/src/mykcal/accounts/service.py` (`sync_display_name` con la regla de 24 h; la consulta por `subject` ya existe en T014) y `backend/src/mykcal/accounts/schemas.py` (`Me`: `id`, `display_name`, `is_admin`, `status`)
- [X] T034 [US3] Implementar `GET /v1/me` en `backend/src/mykcal/accounts/router.py` (solo `get_principal`; 404 `ACCOUNT_NOT_REGISTERED` sin cuenta; 200 con `status` activa o desactivada) y registrar el router en `main.py`
- [X] T035 [US3] Añadir en `backend/tests/privacy/test_all_routes_require_identity.py` la comprobación de que ninguna ruta futura se salta `require_active_account` salvo `/v1/me`, `/v1/registration` y las públicas (lista cerrada)

**Checkpoint**: US3 completa; el backend identifica y rechaza correctamente. Verificar con `uv run pytest -m privacy`.

---

## Phase 4: User Story 2 - Iniciar y cerrar sesión (Priority: P1)

**Goal**: el usuario registrado inicia sesión con Zitadel, la sesión se mantiene entre aperturas, se renueva en silencio y puede cerrarse.

**Independent Test**: con una cuenta existente, iniciar sesión, cerrar la app, reabrirla (sigue dentro), cerrar sesión (vuelve a la pantalla de acceso). Una cuenta desactivada ve el mensaje de cuenta desactivada.

### Tests for User Story 2 ⚠️

- [X] T036 [P] [US2] Test de `SessionStore` en `app/test/auth/session_store_test.dart`: guarda y lee `access_token`, `refresh_token`, `id_token` y `access_token_expires_at`; `clear()` los borra todos
- [X] T037 [P] [US2] Test de `AuthController` en `app/test/auth/auth_controller_test.dart` con `AuthService` simulado: inicio correcto; renovación transparente antes de caducar; renovaciones simultáneas comparten una sola llamada; Zitadel rota el refresh token y se guarda el último; 401 del API → renueva y reintenta una vez; renovación fallida → estado `signedOut` sin descartar los borradores; cerrar sesión borra los tokens aunque falle la revocación o pase el plazo de 5 s
- [X] T038a [P] [US2] Test de `ApiClient` en `app/test/api/api_client_test.dart`: timeout y errores de red → `NetworkFailure`; 5xx → `ServerFailure`; el `code` del cuerpo de error se traduce a `ApiFailure` (FR-015)
- [X] T038 [P] [US2] Test de widgets en `app/test/access/access_screen_test.dart` y `app/test/home/disabled_screen_test.dart`: textos de `contracts/ui-flows.md`, etiquetas semánticas y `expectAccessible` (SC-007) en tema claro y oscuro y con texto al 200 %
- [X] T039 [P] [US2] Test de la máquina de estados de arranque en `app/test/auth/bootstrap_test.dart`: sin tokens → `signedOut`; `/me` 200 activa → `active`; 200 desactivada → `disabled`; 404 `ACCOUNT_NOT_REGISTERED` → `needsRegistration`; sin red/5xx → error con reintento y sin perder estado

### Implementation for User Story 2

- [X] T040 [P] [US2] Implementar `app/lib/core/auth/session_store.dart` con flutter_secure_storage
- [X] T041 [US2] Implementar `app/lib/core/auth/auth_service.dart`: interfaz `AuthService` y `AppAuthService` con flutter_appauth (PKCE, navegador del sistema, scopes `openid profile email offline_access`, `urn:zitadel:iam:org:id:<OIDC_ORG_ID>` y `urn:zitadel:iam:org:project:id:<OIDC_PROJECT_ID>:aud`; opción de abrir la página de registro de Zitadel con `prompt=create`; `refresh`, `revoke` y `end_session` con plazo de 5 s; rechaza un issuer sin `https://`)
- [X] T042 [US2] Implementar `app/lib/core/auth/auth_controller.dart` (Riverpod `Notifier`; `AccountState = signedOut | needsRegistration | active(me) | disabled(me)`; arranque, renovación compartida, cierre de sesión) y completar en `app/lib/core/api/api_client.dart` el reintento tras 401 con renovación
- [X] T043 [P] [US2] Crear `app/lib/features/access/access_screen.dart` (AccesoScreen: «Iniciar sesión» y «Crear cuenta», con `Semantics`/tooltip en cada control)
- [X] T044 [P] [US2] Crear `app/lib/features/home/home_screen.dart` (InicioScreen: saludo con `display_name`; menú «Cerrar sesión»; el menú «Invitaciones» se añade en US4) y `app/lib/features/home/disabled_screen.dart` (CuentaDesactivadaScreen con «Cerrar sesión»)
- [X] T045 [US2] Crear `app/lib/core/router.dart` (o `app/lib/app.dart`) que elige la pantalla según `AccountState`, con la pantalla de error de conexión («Necesitas conexión a Internet», «El servidor no responde») y botón «Reintentar»; `needsRegistration` apunta a un marcador hasta US1

**Checkpoint**: US2 completa; con una cuenta creada a mano en la base de dev se inicia sesión, se mantiene y se cierra.

---

## Phase 5: User Story 1 - Registrarse con código de invitación (Priority: P1)

**Goal**: quien tiene el código vigente crea su cuenta de Mykcal; sin código válido o sin plazas no se crea nada.

**Independent Test**: instalar la app, registrarse con el código vigente y llegar al inicio con la identidad visible; con un código erróneo el alta no se completa (spec US1).

### Tests for User Story 1 ⚠️

- [X] T046 [P] [US1] Test unitario en `backend/tests/unit/test_invitation_code.py`: normalización (`strip`, mayúsculas, sin espacios ni guiones intermedios); generación con `secrets.choice` de 8 caracteres del alfabeto Crockford sin `I L O U` que cumple `^[0-9A-HJKMNP-TV-Z]{8}$`; comparación con `hmac.compare_digest`
- [X] T047 [P] [US1] Test unitario en `backend/tests/unit/test_throttle.py`: fallos 1 a 3 sin espera; desde el 4.º espera `min(30 s × 2^(n−4), 1 h)`; «sin plazas» y «ya registrado» no cuentan como fallo; límite global: 20 fallos en 10 min entre identidades distintas bloquean las altas hasta 10 min después del último fallo, con 19 no
- [X] T048 [P] [US1] Test de contrato de `POST /v1/registration` en `backend/tests/contract/test_registration_contract.py` contra `contracts/openapi.yaml` (201, 400, 401, 409, 429 con `Retry-After`)
- [X] T049 [P] [US1] Test de integración en `backend/tests/integration/test_registration.py`: código vigente → 201 y cuenta `active`; código erróneo, sustituido o inexistente → 400 `INVITATION_INVALID` sin crear cuenta (SC-002); minúsculas y espacios aceptados; 50 cuentas activas → 409 `NO_SEATS` aunque el código sea válido (desactivadas no cuentan, SC-005); ya registrado → 409 `ALREADY_REGISTERED`; el administrador (`ADMIN_SUBJECT`) se registra con cadena vacía y sin código vigente; un no administrador sin código vigente recibe `INVITATION_INVALID`
- [X] T050 [P] [US1] Test de concurrencia en `backend/tests/integration/test_registration_concurrency.py`: dos altas simultáneas con 49 cuentas activas → solo una 201 y la otra `NO_SEATS` (SC-005); un alta con un código que se rota durante el alta no se completa
- [X] T051 [P] [US1] Test de la espera creciente en `backend/tests/integration/test_registration_throttle.py`: tras el 4.º fallo, `429 TOO_MANY_ATTEMPTS` con `Retry-After` sin evaluar el código; un alta correcta borra la fila; la fila se lee con `FOR UPDATE`; 20 fallos repartidos entre 20 `sub` distintos en 10 min → `429` para un `sub` nuevo incluso con el código correcto; el administrador no registra fallos; se borran las filas de `registration_failure` de más de 1 h
- [X] T052 [P] [US1] Test de widgets en `app/test/registration/code_screen_test.dart`: acepta minúsculas y espacios, mensajes de `INVITATION_INVALID` / `NO_SEATS` / `TOO_MANY_ATTEMPTS` (botón desactivado con cuenta atrás), el borrador se conserva sin conexión y al caducar la sesión, `expectAccessible`

### Implementation for User Story 1

- [X] T053 [P] [US1] Implementar `backend/src/mykcal/invitations/codes.py`: `normalize(code)`, `generate()` y `matches(a, b)` según T046
- [X] T054 [P] [US1] Implementar `backend/src/mykcal/accounts/throttle.py`: lectura con `SELECT … FOR UPDATE`, `register_failure` (inserta también en `registration_failure`), `clear`, cálculo de `blocked_until` y `global_block_until()` (≥ 20 fallos en 10 min → bloqueo hasta 10 min tras el último; borra filas de más de 1 h) según `data-model.md` y research R8
- [X] T055 [US1] Implementar `register(subject, code)` en `backend/src/mykcal/accounts/service.py`: con `pg_advisory_xact_lock(<constante>)`, vuelve a leer el código vigente y cuenta `status='active'` dentro del bloqueo; orden: límite global y espera por identidad → 429; administrador sin código → permitido; código inválido → fallo + 400; plazas → 409; inserta `user_account` con el nombre de `userinfo`; borra la fila de `registration_throttle`
- [X] T056 [US1] Implementar `POST /v1/registration` en `backend/src/mykcal/accounts/router.py` (`get_principal`; body `{invitation_code}` con `additionalProperties: false` y `maxLength` 32; 201 con `Me`; `Retry-After` en el 429)
- [X] T057 [P] [US1] Crear `app/lib/features/registration/registration_controller.dart` (llama a `POST /v1/registration`, mapea los códigos de error, `Notifier` del borrador que sobrevive a cambios de pantalla y a la renovación fallida) y `code_screen.dart` (CodigoInvitacionScreen con campo, ayuda «Pídeselo a Erick», «Continuar» y «Cerrar sesión»)
- [X] T058 [US1] Conectar `AccountState.needsRegistration` con CodigoInvitacionScreen en `app/lib/core/router.dart` y pasar a `active` tras el 201

**Checkpoint**: US1 completa; alta con código en el emulador contra el backend local.

---

## Phase 6: User Story 4 - Gestionar el código de invitación (Priority: P2)

**Goal**: el administrador ve el código vigente y las plazas, y lo sustituye; el anterior deja de valer de inmediato.

**Independent Test**: como administrador, cambiar el código; el antiguo ya no permite registrarse y el nuevo sí; un usuario normal no ve ni cambia el código (spec US4).

### Tests for User Story 4 ⚠️

- [X] T059 [P] [US4] Test de contrato de `/v1/admin/invitation` y `/v1/admin/invitation/rotate` en `backend/tests/contract/test_admin_contract.py` contra `contracts/openapi.yaml`
- [X] T060 [P] [US4] Test de integración en `backend/tests/integration/test_invitation_admin.py`: el administrador consulta `code`, `active_accounts`, `max_accounts=50` y `free_seats`; rotar deja un único `is_current` y pone `superseded_at` en el anterior (los anteriores se conservan como histórico); el código anterior da `INVITATION_INVALID` y el nuevo funciona (SC-004); las cuentas existentes no cambian; un no administrador recibe 403 `FORBIDDEN` en ambas rutas; sin código vigente, `code` es `null`
- [X] T061 [P] [US4] Prueba `isolation` en `backend/tests/privacy/test_admin_no_user_data.py` (`@pytest.mark.privacy`): ninguna ruta de `/v1/admin/*` devuelve datos de otros usuarios (solo contadores y el código), FR-006
- [X] T062 [P] [US4] Test de widgets en `app/test/admin/invitations_screen_test.dart` y `app/test/home/home_menu_test.dart`: «Invitaciones» solo aparece con `is_admin`; el diálogo de confirmación de «Cambiar código» es de la app; el código se muestra como `ABCD-EFGH`; `expectAccessible`

### Implementation for User Story 4

- [X] T063 [US4] Implementar `backend/src/mykcal/invitations/service.py`: `get_status()` y `rotate(admin_id)` en una transacción con `pg_advisory_xact_lock` (la misma constante que el alta), que pone `is_current=false` y `superseded_at=now()` en el vigente e inserta el nuevo con `created_by` = cuenta del administrador
- [X] T064 [US4] Implementar `GET /v1/admin/invitation` y `POST /v1/admin/invitation/rotate` en `backend/src/mykcal/invitations/router.py` con `require_admin` (esquema `InvitationStatus` del OpenAPI) y registrarlo en `main.py`
- [X] T065 [P] [US4] Crear `app/lib/features/admin/invitations_controller.dart` y `invitations_screen.dart` (código vigente con botón copiar, «N de 50 cuentas activas · M plazas libres», «Cambiar código» con confirmación)
- [X] T066 [US4] Añadir la opción «Invitaciones» al menú de `app/lib/features/home/home_screen.dart`, visible solo si `is_admin`

**Checkpoint**: US4 completa; rotación comprobada de extremo a extremo.

---

## Phase 7: User Story 5 - App instalable conectada al servidor desplegado (Priority: P1)

**Goal**: el backend está desplegado en Dokploy (dev y prod) y la app se instala desde un enlace y se conecta a él.

**Independent Test**: descargar la app desde el enlace en un móvil Android, instalarla e iniciar sesión contra el servidor desplegado (spec US5).

### Tests for User Story 5 ⚠️

- [X] T067 [P] [US5] Test de integración en `backend/tests/integration/test_apk_download.py`: con un fichero en `APK_DIR`, `GET /descargar/mykcal.apk` sin token devuelve 200 con `Content-Type: application/vnd.android.package-archive`, `Content-Disposition: attachment; filename="mykcal.apk"` y `Cache-Control: no-cache`; sin fichero → 404

### Implementation for User Story 5

- [X] T068 [US5] Implementar `GET /descargar/mykcal.apk` en `backend/src/mykcal/distribution/router.py` (público; lee `APK_DIR/mykcal.apk`; 404 si no existe) y registrarlo en `main.py`
- [X] T069 [P] [US5] Crear `app/scripts/build_apk.sh <prod|dev>` (`flutter build apk --release --flavor <sabor> --dart-define-from-file=config/<sabor>.json`, firma con el keystore local; falla si falta `key.properties`)
- [X] T070 [P] [US5] Crear `app/scripts/publish_apk.sh <prod|dev>` (lee host y ruta de `~/.config/mykcal/publish.env`, fuera del repositorio; `scp` del APK como `mykcal.apk` al volumen del entorno; hace `curl -I` y comprueba 200)
- [ ] T071 [US5] Seguir `specs/001-acceso-y-despliegue/contracts/zitadel-setup.md` (Erick): organización `mykcal` con registro permitido, proyecto `mykcal` (sin «Check authorization on authentication»), apps `mykcal-android` y `mykcal-android-dev` (PKCE, JWT), usuario administrador y SMTP. Anotar `OIDC_ORG_ID`, `OIDC_PROJECT_ID`, `OIDC_CLIENT_ID` y `ADMIN_SUBJECT` y rellenar `app/config/*.json`
- [ ] T072 [US5] **EN PAUSA (Erick, 2026-11-23: por ahora solo producción; Dokploy aún sin hacer)**. Seguir `specs/001-acceso-y-despliegue/contracts/dokploy-setup.md` en el entorno `development` (rama `dev`, `mykcal-bk-dev-api.cruzerick.com`): PostgreSQL sin puerto externo, Application con `backend/Dockerfile`, volumen `/data/apk`, variables de entorno, health check `/v1/health`, relevo `start-first` + `rollback` y HTTPS
- [ ] T073 [US5] **PENDIENTE, sin hacer (Erick lo hará en Dokploy)**. Repetir T072 en el entorno `production` (rama `main`, `mykcal-bk-api.cruzerick.com`), con su propia base y su volumen
- [ ] T074 [US5] Compilar y publicar el APK de dev (`build_apk.sh dev && publish_apk.sh dev`) y recorrer en el emulador y en un móvil real los escenarios 1–12 de `quickstart.md` contra `https://mykcal-bk-dev-api.cruzerick.com`
- [ ] T075 [US5] Con el entorno de prod ya creado (T073) y la feature fusionada en `dev`, comprobar `GET /v1/health` en `https://mykcal-bk-api.cruzerick.com` y dejar documentado el paso de publicación (merge `dev` → `main`, `build_apk.sh prod && publish_apk.sh prod`, escenarios 1, 4, 5 y 10 de `quickstart.md`, alta cronometrada < 5 min, SC-001). Ese merge a `main` es la publicación a producción y se hace tras probar el conjunto en `dev`, fuera del cierre de esta feature

**Checkpoint**: todas las historias completas y desplegadas.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T076 [P] Escribir `README.md` en la raíz (arranque local, tests, sabores, publicación del APK) y `backend/README.md` si hace falta
- [X] T077 [P] Ejecutar `uv run ruff check` y `uv run ruff format --check` en `backend/` y `flutter analyze` en `app/`; corregir los avisos
- [X] T078 Ejecutar la batería completa: `uv run pytest` (incluido `-m privacy`) y `flutter test`; todo en verde
- [X] T079 Revisar el Constitution Check de `plan.md` contra el código: sin datos de salud ni email almacenados, sin tokens en logs, rutas públicas = lista cerrada, todos los textos en `app_es.arb`
- [X] T080 Proponer a Erick, con `/speckit-constitution`, la enmienda PATCH de la constitución: (1) «Dokploy: Application + servicio PostgreSQL» y (2) «alta en Mykcal solo con código de invitación» en lugar de «Registro solo con código», ambas registradas en Complexity Tracking
- [ ] T081 Ejecutar `quickstart.md` completo (escenarios 1–12 y sección 4) y anotar el resultado en el PR de la feature hacia `dev`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (1)**: sin dependencias.
- **Foundational (2)**: depende de Setup; bloquea todas las historias.
- **US3 (3)** → **US2 (4)** → **US1 (5)** → **US4 (6)**: cada una usa lo anterior (`/me` → sesión en la app → alta → administración).
- **US5 (7)**: T067–T070 solo dependen de la Fase 2; T071–T073 (Zitadel y Dokploy) pueden hacerse en cuanto exista la Fase 2 y deben estar hechos antes de T074. T074–T075 requieren US1–US4 integradas.
- **Polish (8)**: depende de todas las historias.

### Dentro de cada historia

- Las pruebas se escriben primero y deben fallar.
- Modelos → servicios → rutas → app.
- T017 depende de T014 y T016; T018 depende de T011, T016 y T017; T034 depende de T033 y T017; T055 depende de T053 y T054; T058 depende de T045 y T057.

### Parallel Opportunities

- Setup: T003, T004, T006, T007 y T008 en paralelo tras T001/T002.
- Fase 2: T010, T011, T014 en paralelo; T021–T023 y T024–T027 (app) en paralelo con el backend.
- US1: T046–T052 (pruebas) en paralelo; T053 y T054 en paralelo; la app (T057) puede avanzar a la vez que el backend.
- US5: T069 y T070 en paralelo con T071–T073 (trabajo manual de Erick).

### Parallel Example: User Story 1

```bash
Task: "Test unitario del código en backend/tests/unit/test_invitation_code.py"
Task: "Test de la espera creciente en backend/tests/unit/test_throttle.py"
Task: "Test de integración del alta en backend/tests/integration/test_registration.py"
Task: "Test de widgets de la pantalla del código en app/test/registration/code_screen_test.dart"
```

---

## Implementation Strategy

### MVP First (US3 + US2 + US1)

1. Fases 1 y 2.
2. US3: el backend identifica y rechaza (`pytest -m privacy` verde).
3. US2: sesión en la app contra el backend local con una cuenta creada a mano.
4. US1: alta con código. **Parar y validar** en el emulador.
5. Desplegar a dev (parte de US5) antes de seguir con US4.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. US3 → US2 → US1: acceso completo.
3. US4: el administrador gestiona el código (P2; si el plazo aprieta, el primer código puede generarse a mano en la base).
4. US5: despliegue a dev, APK, y luego a prod por el flujo `feature → dev → main`.

### Notas

- [P] = ficheros distintos y sin dependencias pendientes.
- El flujo de ramas es `001-acceso-y-despliegue` → `dev` → `main`; nunca se hace commit directo en `main`.
- Hacer commit tras cada tarea o grupo lógico. El keystore, `.env` y `key.properties` nunca se versionan.
- Antes de usar una librería, consultar su documentación actual con Context7.
