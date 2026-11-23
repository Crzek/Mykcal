# Implementation Plan: Acceso por invitación y sesión

**Branch**: `001-acceso-y-despliegue` | **Date**: 2026-11-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-acceso-y-despliegue/spec.md`

## Summary

Esta feature crea el esqueleto del monorepo: backend FastAPI + PostgreSQL y app Flutter Android.
Incluye el alta por código de invitación, la sesión con Zitadel y el despliegue en Dokploy en
dos entornos.

- **Registro (opción A)**: la persona crea su usuario con el autorregistro de una organización
  `mykcal` propia en `mg-zitadel.cruzerick.com`. Mykcal solo crea la cuenta interna si el código
  es el vigente y hay menos de 50 cuentas activas.
- **Validación del token**: el backend valida el JWT en local contra el JWKS, con `aud` igual al
  proyecto `mykcal`.
- **Administrador**: el que tenga `sub` igual a `ADMIN_SUBJECT`. Rota el código y ve las plazas.
- **APK**: lo sirve el propio backend en `/descargar/mykcal.apk`.

| Entorno | Rama | API |
|---|---|---|
| Producción | `main` | `https://mykcal-bk-api.cruzerick.com` |
| Desarrollo | `dev` | `https://mykcal-bk-dev-api.cruzerick.com` |

## Technical Context

**Language/Version**: Python 3.12 (backend); Dart ≥ 3.5 / Flutter ≥ 3.32 (app)

**Primary Dependencies**:
- Backend: FastAPI, SQLAlchemy 2 async + asyncpg, Alembic, pydantic-settings, structlog, httpx,
  pyjwt[crypto].
- App: flutter_riverpod, dio, flutter_appauth, flutter_secure_storage, flutter_localizations.

**Storage**: PostgreSQL 16, con una base dedicada por entorno en Dokploy. Tablas:
`user_account`, `invitation_code`, `registration_throttle` y `registration_failure`. En el móvil solo se guardan los
tokens, en el almacenamiento seguro.

**Testing**:
- Backend: pytest + pytest-asyncio + testcontainers (PostgreSQL), Zitadel simulado con claves
  RSA de prueba y validación contra `contracts/openapi.yaml`.
- App: flutter_test + mocktail, con las guías de accesibilidad. Flujos manuales en el emulador.

**Target Platform**: contenedor Linux en Dokploy (Docker Swarm + Traefik); Android API ≥ 24.

**Project Type**: móvil + API (monorepo `backend/` + `app/`)

**Performance Goals**: ninguno formal (decisión de Erick en la spec). SC-001: alta completa en
menos de 5 min.

**Constraints**:
- Sin servicios reales en las pruebas.
- Sin tokens ni credenciales en los logs.
- Los textos están en español y externalizados.
- WCAG 2.1 AA.
- La app requiere conexión.

**Scale/Scope**: ≤ 50 cuentas activas por entorno, 5 pantallas y 5 rutas de API.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| I. IA propone, usuario confirma | N/A | Sin IA en esta feature |
| II. Base de alimentos única fuente | N/A | — |
| III. IA opcional | N/A | — |
| IV. Privacidad y salud | ✅ | No se guardan datos de salud ni el email; solo `sub` y nombre visible. El consentimiento llega en la 002 |
| V. Aislamiento y seguridad | ✅ con excepción | JWT contra el JWKS en todas las rutas salvo `/v1/health` y `/descargar/mykcal.apk`, que no exponen datos (ver Complexity Tracking). Identidad = `sub`. Las cuentas desactivadas solo pueden leer `/v1/me`. El administrador no ve datos de otros (FR-006) |
| VI. Determinista y pruebas sin servicios reales | ✅ | Zitadel simulado con JWKS de prueba; pruebas `privacy` sobre todas las rutas (R15) |
| VII. Simplicidad | ✅ | Sin Redis, colas ni Management API. El límite de intentos y el de plazas van en PostgreSQL. Sin introspección (R4) |
| VIII. Accesible, español, métrica | ✅ | ARB `es`, tema del sistema, `textScaler`, guías de contraste y etiquetas en las pruebas (R14) |
| IX. Entrega vertical y desplegada | ✅ | Backend en Dokploy (dev y prod) y APK descargable de cada entorno; flujos probados en el emulador |
| X. Observabilidad sin contenido sensible | ✅ | structlog JSON con lista blanca; todos los errores 5xx registrados; prueba de que un token no aparece en los logs (R13) |
| Restricción: Docker Compose en Dokploy | ⚠️ desviación | Se usa Application (Dockerfile) + servicio PostgreSQL de Dokploy, el esquema de Ligón, por decisión de Erick (ver Complexity Tracking) |
| Ramas y entornos | ✅ | Rama `dev` creada desde `main`; esta rama nace de `dev` |

**Re-check post-design**: el diseño de Phase 1 (data-model, contracts) mantiene todos los ✅ sin
violaciones nuevas.

**Gate: PASS** con tres excepciones justificadas abajo.

## Project Structure

### Documentation (this feature)

```text
specs/001-acceso-y-despliegue/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── openapi.yaml        # contrato vivo del API
│   ├── zitadel-setup.md    # organización, proyecto y apps en mg-zitadel
│   ├── dokploy-setup.md    # dos entornos, variables, volumen del APK
│   └── ui-flows.md         # pantallas, estados y mensajes
└── tasks.md                # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── Dockerfile
├── docker-entrypoint.sh          # migrate → uvicorn
├── docker-compose.dev.yml        # PostgreSQL local
├── .env.example
├── pyproject.toml / uv.lock
├── alembic.ini
├── alembic/versions/0001_access.py
├── src/mykcal/
│   ├── main.py                   # app, manejadores de error, rutas públicas
│   ├── config.py                 # Settings (falla al arrancar si falta algo)
│   ├── db.py                     # engine/sesión async
│   ├── migrate.py                # Alembic con bloqueo consultivo
│   ├── logging.py                # structlog con lista blanca
│   ├── core/
│   │   ├── auth.py               # JWKS, validación JWT, Principal, dependencias
│   │   ├── userinfo.py           # nombre visible (R5)
│   │   └── errors.py             # ErrorBody y códigos
│   ├── accounts/                 # user_account, /v1/me, /v1/registration, throttle
│   ├── invitations/              # invitation_code, /v1/admin/invitation[/rotate]
│   └── distribution/             # /descargar/mykcal.apk
└── tests/
    ├── conftest.py               # testcontainers, Zitadel simulado
    ├── contract/                 # contra contracts/openapi.yaml
    ├── privacy/                  # todas las rutas rechazan sin identidad / desactivadas
    ├── integration/              # alta, plazas, rotación, concurrencia, throttle
    └── unit/                     # normalización y generación de código, backoff

app/
├── pubspec.yaml
├── l10n.yaml
├── config/dev.json, prod.json    # OIDC_* y API_BASE_URL (no secretos)
├── android/app/build.gradle      # sabores prod/dev, applicationIdSuffix .dev, appAuthRedirectScheme
├── scripts/build_apk.sh, publish_apk.sh
├── lib/
│   ├── main.dart
│   ├── l10n/app_es.arb
│   ├── core/
│   │   ├── auth/                 # AuthService (appauth), SessionStore, AuthController
│   │   ├── api/                  # cliente dio, interceptor de token, errores tipados
│   │   └── theme/
│   └── features/
│       ├── access/               # AccesoScreen
│       ├── registration/         # CodigoInvitacionScreen + borrador
│       ├── home/                 # InicioScreen, CuentaDesactivadaScreen
│       └── admin/                # InvitacionesScreen
└── test/                         # widgets + a11y, controladores con mocks
```

**Structure Decision**: monorepo con `backend/` (FastAPI, paquete `mykcal` en `src/`) y `app/`
(Flutter, con sabores `prod` y `dev`). Es la misma organización que Ligón, para reutilizar su
patrón de autenticación y despliegue.

## Complexity Tracking

| Violación | Por qué hace falta | Alternativa más simple rechazada porque |
|---|---|---|
| Rutas sin identidad: `GET /v1/health` y `GET /descargar/mykcal.apk` (principio V: «100% de endpoints») | Dokploy y Swarm necesitan un health check sin credenciales. El APK se descarga **antes** de tener cuenta (FR-018, US5) | Exigir token a la descarga hace imposible instalar la app. Ninguna de las dos rutas devuelve datos de usuario, y las pruebas `privacy` fijan la lista exacta de rutas públicas |
| Registro abierto en Zitadel (autorregistro); la constitución dice «Registro solo con código de invitación» | La opción A (decisión de Erick) evita guardar credenciales de la Management API. El código gatea la cuenta de Mykcal: sin ella ninguna ruta funciona (salvo `/v1/me` y `/v1/registration`) | La opción B (alta desde el backend con la Management API) exige una service account con permisos de administración. **Mitigación**: límite por identidad y global de intentos (R8). **Propuesta**: reformular la restricción a «alta en Mykcal solo con código» |
| Despliegue como Application + PostgreSQL de Dokploy en lugar de «Docker Compose» (restricción técnica) | Erick lo pidió (2026-11-22). Es el esquema probado en Ligón, con relevo `start-first`/rollback y bases gestionadas por Dokploy | Con Compose, el relevo y la base en el mismo stack se gestionan a mano. **Propuesta**: enmendar la constitución (PATCH) para decir «Dokploy (Application + servicio PostgreSQL)» |

## Puntos que Erick debe confirmar o hacer antes de implementar

1. **Organización nueva `mykcal`** en Zitadel (R2). La de Ligón no permite registro y obliga a
   MFA. Erick necesita un usuario nuevo en esa organización para ser `ADMIN_SUBJECT`.
2. **SMTP** configurado en la instancia de Zitadel. Sin él, el autorregistro no se completa.
3. **Acceso SSH/scp** al servidor de Dokploy para publicar el APK en el volumen (R9).
4. **Keystore de release** creado y guardado fuera del repositorio.

