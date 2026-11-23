# Implementation Plan: Onboarding, objetivo diario y baja

**Branch**: `002-onboarding-y-objetivo` | **Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-onboarding-y-objetivo/spec.md`

## Summary

Tras el alta de la 001, el usuario pasa por un onboarding de dos pasos: consentimiento de datos de
salud y perfil. Al guardar el perfil, el backend calcula el objetivo diario y la app lo muestra.
Después, el usuario puede editar el perfil o el objetivo y darse de baja desde los ajustes.

- **Cálculo**: función pura en el backend (`mykcal/targets/calc.py`) con `Decimal` y redondeo
  `ROUND_HALF_UP` al final. Mifflin-St Jeor × actividad × objetivo, mínimos de 1.500/1.200 kcal y
  macros, fibra y micros según la spec (R1–R3). Los 13 casos de `contracts/calc-cases.md` fijan el
  resultado.
- **Consentimiento**: puerta en el servidor. La dependencia `require_consent` protege todas las
  rutas de datos de salud y una prueba `privacy` lo fija (R8, R9).
- **Objetivo**: historial de versiones con una sola vigente, para que la 004 sepa qué objetivo
  regía cada día. Cada versión guarda los datos con los que se calculó (R4, R5).
- **Recálculo**: al cambiar el perfil, el servidor recalcula si el objetivo es calculado y solo
  propone el cambio si está editado a mano (R12).
- **Onboarding reanudable**: `GET /v1/me` devuelve `onboarding: consent | profile | done` y la app
  elige la pantalla con ese dato (R10).
- **Baja**: `POST /v1/me/deactivation` desactiva la cuenta de Mykcal y la app cierra la sesión. El
  usuario de Zitadel no se toca (R15).

## Technical Context

**Language/Version**: Python 3.12 (backend); Dart ≥ 3.5 / Flutter ≥ 3.32 (app). Sin cambios respecto a la 001.

**Primary Dependencies**: las de la 001 y la 008, sin añadidos (R17).

**Storage**: PostgreSQL 16. La migración `0002_onboarding` crea `health_consent`, `user_profile`,
`weight_entry` y `daily_target` (`data-model.md`). En el móvil no se guarda nada nuevo.

**Testing**:
- Backend: pytest. Unitarias del cálculo con la tabla de casos; integración con testcontainers;
  contrato contra `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, ampliado según
  `contracts/api-changes.md`; `privacy` de consentimiento, aislamiento y baja.
- App: flutter_test + mocktail, con `MykcalApi` sustituida. Pruebas de widget y de accesibilidad
  de cada pantalla nueva, y una prueba pura del aviso de macros (FR-017).

**Target Platform**: Android API ≥ 24; contenedor Linux en Dokploy.

**Project Type**: móvil + API (monorepo `backend/` + `app/`).

**Performance Goals**: ninguno formal. SC-001: onboarding completo en menos de 3 min.

**Constraints**:
- Ningún dato de salud sin consentimiento, comprobado en el servidor (principio IV).
- Cálculo determinista y sin `float` (principio VI).
- Sin valores de perfil, peso ni objetivo en los logs (principio X).
- Textos en `app_es.arb`, formato numérico español y WCAG 2.1 AA (FR-020).
- Sin conexión, la app avisa y conserva lo escrito.

**Scale/Scope**: 4 tablas, 7 rutas nuevas, 1 campo nuevo en `Me`, 6 pantallas o diálogos nuevos y
2 pantallas modificadas (inicio y acceso).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| I. La IA propone | N/A | Sin IA. La pantalla de clave de IA del onboarding llega en la 006. |
| II. Base de alimentos | N/A | El objetivo no es un dato de alimentos. |
| III. IA opcional | ✅ | El onboarding termina sin pedir clave de IA. |
| IV. Privacidad y salud | ✅ | `require_consent` en todas las rutas de salud. El consentimiento se guarda con hora del servidor y versión del texto (R8, R9). Prueba `privacy` con lista cerrada de rutas de salud. Perfil, peso y objetivo solo en el servidor. |
| V. Aislamiento y seguridad | ✅ | Rutas nuevas tras `require_active_account`. Sin identificadores de otros usuarios en las rutas; todas las consultas filtran por `user_id`, con prueba de aislamiento. La baja deja la cuenta sin operar (`ACCOUNT_DISABLED`). Ninguna ruta pública nueva. |
| VI. Determinista y pruebas sin servicios reales | ✅ | `calculate()` pura con `Decimal` y 13 casos de referencia más una rejilla de propiedades (R1, R2, `contracts/calc-cases.md`). Zitadel simulado como en la 001. |
| VII. Simplicidad | ✅ | Sin dependencias ni infraestructura nuevas (R17). El historial del objetivo es una columna y un índice, justificado por la 004 (R4). El cálculo existe una sola vez (R1). |
| VIII. Accesible, español, métrica | ✅ | Textos en ARB, `NumberFormat` `es`, unidades métricas, errores junto al campo y anunciados, avisos con icono y texto (`contracts/ui-flows.md`). |
| IX. Entrega vertical | ✅ | Se cierra con el APK de `dev` en el emulador y el móvil, el backend en Dokploy `dev` y los escenarios de `quickstart.md`. |
| X. Observabilidad | ✅ | Solo eventos sin datos de salud (`consent_recorded`, `profile_saved`, `target_saved` con `source`, `account_deactivated`), con el `user_id` interno. `VALIDATION_ERROR` devuelve nombres de campo, nunca valores (R14). Prueba de que los valores del perfil no aparecen en los logs. |
| Ramas y entornos | ✅ | La rama sale de `origin/dev` (que ya incluye la 001 y la 008) y volverá a `dev` por PR. |

**Resultado**: pasa sin excepciones.

**Re-check tras el diseño (Phase 1)**: sin cambios. El contrato añade rutas autenticadas y ninguna
pública. El modelo de datos filtra todo por `user_id` y la prueba `privacy` cubre las rutas nuevas.

## Project Structure

### Documentation (this feature)

```text
specs/002-onboarding-y-objetivo/
├── plan.md
├── research.md              # R1–R17
├── data-model.md            # 4 tablas, transiciones del objetivo, reglas de acceso
├── quickstart.md            # pruebas, migración y 21 escenarios
├── contracts/
│   ├── api-changes.md       # cambios al openapi.yaml vivo de la 001
│   ├── calc-cases.md        # casos de referencia del cálculo (SC-002)
│   └── ui-flows.md          # pantallas, estados y mensajes
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── alembic/versions/0002_onboarding.py          # nuevo
├── src/mykcal/
│   ├── main.py                                  # incluye los routers nuevos
│   ├── core/
│   │   ├── auth.py                              # + require_consent
│   │   └── errors.py                            # + códigos nuevos, ErrorBody.fields
│   ├── accounts/
│   │   ├── router.py                            # Me.onboarding, POST /v1/me/deactivation
│   │   ├── schemas.py                           # Me + onboarding
│   │   └── service.py                           # deactivate() con el bloqueo de R7 (001)
│   ├── consent/                                 # nuevo: models, router, service (CURRENT_CONSENT_VERSION)
│   ├── profile/                                 # nuevo: models (user_profile, weight_entry), schemas, router, service
│   └── targets/                                 # nuevo
│       ├── calc.py                              # función pura (R1–R3)
│       ├── models.py                            # daily_target
│       ├── schemas.py
│       ├── router.py                            # /v1/target, /v1/target/recalculate
│       └── service.py                           # versiones, recálculo y propuesta (R4, R12)
└── tests/
    ├── unit/test_target_calc.py                 # calc-cases.md + rejilla
    ├── integration/
    │   ├── test_consent.py
    │   ├── test_onboarding.py                   # perfil + peso + objetivo en una transacción
    │   ├── test_recalculation.py                # applied / proposed / none, recalculate
    │   ├── test_manual_target.py
    │   └── test_deactivation.py
    ├── contract/test_onboarding_contract.py
    └── privacy/
        ├── test_all_routes_require_identity.py  # lista de rutas ampliada
        ├── test_consent_gate.py                 # nuevo (SC-003)
        ├── test_user_isolation_health.py        # nuevo
        └── test_logs_no_secrets.py              # + valores de perfil

app/
├── lib/
│   ├── app.dart                                 # AppGate mira me.onboarding
│   ├── core/api/
│   │   ├── models.dart                          # Me.onboarding, Profile, DailyTarget, TargetValues…
│   │   └── mykcal_api.dart                      # 7 métodos nuevos
│   ├── core/format/numbers.dart                 # nuevo: NumberFormat es, coma decimal
│   ├── core/auth/auth_controller.dart           # aviso accountDeactivated, deactivate()
│   ├── features/
│   │   ├── consent/consent_screen.dart          # nuevo
│   │   ├── profile/                             # nuevo: profile_screen.dart, profile_controller.dart (borrador)
│   │   ├── target/                              # nuevo: target_screen.dart, target_edit_screen.dart,
│   │   │                                        #        target_controller.dart, macro_check.dart (FR-017)
│   │   ├── settings/settings_screen.dart        # nuevo: perfil, objetivo, baja
│   │   ├── home/home_screen.dart                # tarjeta del objetivo, entrada «Ajustes»
│   │   └── access/access_screen.dart            # aviso de baja
│   └── l10n/app_es.arb                          # textos nuevos, incluido el consentimiento
└── test/
    ├── consent/, profile/, target/, settings/   # widgets + a11y
    ├── target/macro_check_test.dart
    └── home/home_menu_test.dart                 # + Ajustes
```

**Structure Decision**: se mantiene el monorepo de la 001. En el backend, cada entidad nueva va en
su paquete (`consent`, `profile`, `targets`), como `accounts` e `invitations`. `weight_entry` va
en `profile` por ahora; la 007 puede moverlo a un paquete `weights` cuando añada sus rutas. En la
app, una carpeta por pantalla en `features/`, como hasta ahora.

## Complexity Tracking

Sin violaciones que justificar.

## Puntos que Erick debe confirmar o hacer antes de implementar

1. **Texto del consentimiento** (supuesto de la spec, R8). Hace falta la redacción definitiva para
   `app_es.arb`; la primera versión será `2026-11-1`. Mientras tanto se usa un texto provisional
   marcado como tal.
2. **Edad sin fecha de nacimiento** (R7): la edad no avanza sola; el usuario la actualiza en el
   perfil.
3. **Baja sin tocar Zitadel** (R15): el usuario sigue existiendo en Zitadel, pero no puede usar
   Mykcal. Borrarlo exigiría la Management API, que la 001 descartó.
