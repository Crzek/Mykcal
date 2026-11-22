# Data Model: 001 — Acceso por invitación y sesión

PostgreSQL 16, con una base por entorno (research R10). La migración Alembic `0001_access` crea
las tres tablas. Todas las fechas se guardan en `timestamptz` (UTC).

## user_account

Persona registrada en Mykcal (entidad «Usuario» de la spec).

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()`. Identificador interno; es lo que aparece en los logs |
| `subject` | `text` NOT NULL UNIQUE | `sub` del JWT de Zitadel (FR-010). Nunca sale en los logs |
| `display_name` | `text` NOT NULL | De `userinfo` (research R5), 1–200 caracteres |
| `display_name_synced_at` | `timestamptz` NOT NULL | Última sincronización con `userinfo` |
| `status` | `text` NOT NULL | `CHECK (status IN ('active','disabled'))`, por defecto `active` |
| `created_at` | `timestamptz` NOT NULL | Fecha del alta |
| `disabled_at` | `timestamptz` NULL | No es nulo ⇔ `status='disabled'` (CHECK) |

- **Índice**: `ix_user_account_active` parcial `WHERE status='active'`, para contar plazas.
- **No se guarda**: email ni `is_admin`. `is_admin` se calcula comparando `subject` con
  `ADMIN_SUBJECT` (research R6).
- **Transiciones de estado**: `active → disabled`. La transición la implementa la feature 002;
  aquí solo se respeta. No hay vuelta atrás desde la app.
- **Límite de plazas** (FR-002): `count(*) WHERE status='active' < 50`, comprobado dentro del
  bloqueo de R7. La constante `MAX_ACTIVE_ACCOUNTS = 50` está en el código.

## invitation_code

Entidad «Código de invitación» de la spec.

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | `uuid` PK | |
| `code` | `text` NOT NULL UNIQUE | 8 caracteres normalizados (`^[0-9A-HJKMNP-TV-Z]{8}$`) |
| `is_current` | `boolean` NOT NULL | Índice único parcial `WHERE is_current` → como máximo uno (FR-003) |
| `created_at` | `timestamptz` NOT NULL | |
| `created_by` | `uuid` NOT NULL FK → `user_account.id` | La cuenta del administrador |
| `superseded_at` | `timestamptz` NULL | No es nulo ⇔ `is_current=false` (CHECK) |

- **Rotación** (FR-004): en una transacción con el bloqueo de R7, se pone `is_current=false` y
  `superseded_at=now()` en el vigente y se inserta el nuevo con `is_current=true`. Los códigos
  anteriores quedan como histórico y nunca se borran.
- **Sin código vigente**: solo el administrador puede registrarse (arranque, R6).

## registration_throttle

Fallos consecutivos de alta por identidad (FR-013, research R8).

| Columna | Tipo | Reglas |
|---|---|---|
| `subject` | `text` PK | `sub` de quien lo intenta, que todavía no tiene cuenta |
| `consecutive_failures` | `integer` NOT NULL | ≥ 1 |
| `last_failure_at` | `timestamptz` NOT NULL | |
| `blocked_until` | `timestamptz` NULL | `last_failure_at + min(30 s·2^(n−4), 1 h)` si n ≥ 4 |

- **Qué cuenta como fallo**: un código erróneo o sustituido. **No** cuentan «sin plazas» ni
  «ya registrado».
- Un alta correcta borra la fila.
- Se lee con `SELECT … FOR UPDATE`.

## registration_failure

Fallos de alta de todas las identidades, para el límite global (research R8).

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | `bigserial` PK | |
| `failed_at` | `timestamptz` NOT NULL | Índice `ix_registration_failure_failed_at` |

- Solo cuenta el instante; no guarda `sub` ni el código probado.
- **Regla**: si `count(*) WHERE failed_at > now() - interval '10 minutes'` ≥ 20, las altas se
  rechazan con 429 hasta 10 min después del último fallo.
- Se borran las filas con más de 1 h en cada intento de alta.

## Valores en memoria (no se guardan)

### Identidad autenticada (`Principal`)

Sale de un JWT válido (research R4):
- `subject`
- `account`: la fila de `user_account`, o `None` si no hay cuenta
- `is_admin`

### Reglas de acceso por ruta

| Ruta | Sin token / inválido | Sin cuenta Mykcal | Cuenta desactivada | Sin ser admin |
|---|---|---|---|---|
| `/v1/health`, `/descargar/*` | permitido (público) | — | — | — |
| `GET /v1/me` | 401 | 404 `ACCOUNT_NOT_REGISTERED` | 200 con `status: disabled` | — |
| `POST /v1/registration` | 401 | permitido | 409 `ALREADY_REGISTERED` | — |
| `/v1/admin/*` | 401 | 403 `ACCOUNT_NOT_REGISTERED` | 403 `ACCOUNT_DISABLED` | 403 `FORBIDDEN` |
| Cualquier otra ruta futura | 401 | 403 `ACCOUNT_NOT_REGISTERED` | 403 `ACCOUNT_DISABLED` | — |

Las reglas se aplican con una dependencia de FastAPI por defecto (`require_active_account`). Las
pruebas `privacy` comprueban que ninguna ruta se la salta, salvo las de la lista explícita.

## Estado en la app (no persistido salvo los tokens)

- **Sesión** (`flutter_secure_storage`): `access_token`, `refresh_token`, `id_token` y
  `access_token_expires_at`.
- **`AccountState`**: `signedOut | needsRegistration | active(me) | disabled(me)`.
- **Borrador del formulario de código**: el texto introducido. Vive en un `Notifier` y se
  conserva sin conexión y si caduca la sesión (FR-015).
