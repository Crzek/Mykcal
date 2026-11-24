# Implementation Plan: Diario de comidas y resumen diario

**Branch**: `004-diario-de-comidas` | **Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-diario-de-comidas/spec.md`

## Summary

El usuario registra lo que come en cinco comidas fijas al día y ve al momento cuánto ha consumido
y cuánto le queda frente al objetivo que regía ese día. Puede editar, mover y borrar entradas (con
deshacer de 10 s) y navegar a cualquier día desde su alta hasta hoy. Inicio pasa a ser el diario.

- **Modelo**: una sola tabla `diary_entry`. «Día» y «Comida» son agrupaciones (R4). Cada entrada
  copia el nombre y los 12 nutrientes **por 100** del alimento, y guarda la cantidad en g/ml y,
  si aplica, las raciones. Sus valores se calculan siempre desde esa copia, así que cambiar o
  borrar el alimento no la altera (R5, FR-004).
- **Día**: fecha local enviada por la app. El objetivo del día es la versión de `daily_target`
  vigente al final de ese día local; la app envía `utc_offset_min` para fijar ese instante (R1,
  R3, FR-011).
- **Resumen**: función pura con `sum_nutrients` de la 003. Redondea solo los totales y calcula
  `restante = objetivo − consumido redondeado`, que puede ser negativo (exceso). Así siempre se
  cumple SC-002 (R10).
- **API**: 5 rutas `/v1/diary/**` con consentimiento. Las que modifican devuelven el día completo
  (R9, SC-003). Borrado lógico y `restore` durante 60 s (R8).
- **App**: Inicio = diario con navegación de días, tarjeta de resumen, detalle de micros y las 5
  comidas. Añadir reutiliza la búsqueda y el escáner de la 003 en modo selección, con una hoja de
  cantidad con vista previa en vivo (R13, `contracts/ui-flows.md`).

## Technical Context

**Language/Version**: Python 3.12 (backend); Dart ≥ 3.5 / Flutter ≥ 3.32 (app). Sin cambios.

**Primary Dependencies**: las de la 003, sin añadidos (R16). Backend: FastAPI, SQLAlchemy async,
Alembic. App: Riverpod, dio, intl.

**Storage**: PostgreSQL 16. La migración `0004_diary` crea `diary_entry` (`data-model.md`). En el
móvil no se guarda nada nuevo.

**Testing**:
- Backend: pytest.
  - Unitarias: `summary.py` y `day_end_utc` con los casos de `contracts/summary-cases.md`, y la
    conversión de raciones.
  - Integración con testcontainers: ciclo de vida de la entrada, objetivo por día, límites de
    fecha y copia del alimento (SC-004).
  - Contrato contra `openapi.yaml` 0.4.0.
  - `privacy`: aislamiento (SC-005), consentimiento, identidad y registros.
- App: flutter_test + mocktail.
  - Prueba pura de `entry_math.dart`.
  - Widgets y accesibilidad del diario, la tarjeta de resumen, el detalle y la hoja de cantidad.
  - Navegación de días (límites, medianoche) y deshacer.

**Target Platform**: Android API ≥ 24; contenedor Linux en Dokploy.

**Project Type**: móvil + API (monorepo `backend/` + `app/`).

**Performance Goals**:
- SC-003: cada cambio devuelve el día en un solo viaje, una consulta por índice
  `(user_id, entry_date)` sobre decenas de filas, en menos de 100 ms en el servidor.
- SC-001: añadir en menos de 30 s, con la búsqueda de la 003 (< 300 ms) y una hoja de un campo.

**Constraints**:
- Valores solo desde la base de alimentos, copiados al registrar (principio II, FR-003, FR-004).
- Entradas aisladas por usuario: `404` para las ajenas (principio V, FR-013).
- Sin nombres, cantidades ni fechas en los registros (principio X, R12).
- Español, métrica, WCAG 2.1 AA y exceso no solo con color (FR-014, R14).
- Requiere conexión. Sin ella, la hoja conserva lo escrito (restricción técnica).

**Scale/Scope**: 1 tabla, 5 rutas, 1 campo en `Me`, 3 pantallas u hojas nuevas y 3 modificadas
(Inicio, búsqueda y resultado del escáner).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| I. La IA propone | N/A | Sin IA. La 006 creará entradas con estas mismas rutas tras la confirmación del usuario. |
| II. Base de alimentos | ✅ | `POST /v1/diary/entries` solo recibe `food_id` y cantidad. Los valores se copian de `food` y se calculan en el servidor. No hay forma de enviar valores a mano (FR-003). |
| III. IA opcional | ✅ | El diario funciona entero sin clave de IA. |
| IV. Privacidad y salud | ✅ | Las 5 rutas exigen consentimiento (`require_consent`) y se añaden a `test_consent_gate`. No hay fotos. |
| V. Aislamiento y seguridad | ✅ | Todas las consultas filtran por `user_id`. Una entrada ajena da `404 ENTRY_NOT_FOUND` indistinguible. Añadir un personalizado ajeno da `404 FOOD_NOT_FOUND`. Prueba `test_user_isolation_diary` sobre las 5 rutas (SC-005). Ninguna ruta pública nueva. |
| VI. Determinista y sin servicios reales | ✅ | `summary.py` y `day_end_utc` son funciones puras con `Decimal` y casos fijos. El reloj se inyecta (`clock.utcnow`) para el plazo de `restore` y los límites de fecha. Ningún servicio externo. |
| VII. Simplicidad | ✅ | Una tabla, sin tablas de día ni de comida. Sin caché, sin cálculo en dos sitios (el servidor manda, R9). Ninguna dependencia nueva. |
| VIII. Accesible, español, métrica | ✅ | ARB, g/ml/kcal, formato numérico español, exceso con texto e icono, semántica por fila (R14, `contracts/ui-flows.md`). |
| IX. Entrega vertical | ✅ | Usable en el móvil: Inicio es el diario. Antes de fusionar: pruebas y escenarios contra el backend local. Se cierra tras desplegar desde `main` y repetir los escenarios 1, 2, 10 y 16 (`quickstart.md` §5). |
| X. Observabilidad | ✅ | Eventos `diary_entry_*` con `user_id`, `meal` y duración, sin alimento, cantidad ni fecha. Se amplía `test_logs_no_secrets` (R12). Los errores 500 se registran con el manejador existente. |
| Ramas y entornos | ✅ | La rama `004-diario-de-comidas` sale de `dev` (con la 001, 002, 003 y 008) y volverá a `dev` por PR. |
| Flujo: preguntas abiertas resueltas | ✅ | Las tres dudas de la spec se cerraron en `/speckit-clarify` (2026-11-24). |

**Resultado**: pasa sin excepciones.

**Re-check tras el diseño (Phase 1)**: sin cambios.
- El contrato añade 5 rutas autenticadas con consentimiento y ninguna pública.
- `data-model.md` guarda la copia por 100 con `CHECK` de rangos e índice parcial por usuario y día.
- `Me.registered_at` no expone datos de salud.
- La 005 tendrá `food_id` y la copia que necesita para recientes y copiar comidas.

## Project Structure

### Documentation (this feature)

```text
specs/004-diario-de-comidas/
├── plan.md
├── research.md              # R1–R16
├── data-model.md            # diary_entry, objetivo por día, ciclo de vida, acceso
├── quickstart.md            # pruebas, migración y 21 escenarios
├── contracts/
│   ├── api-changes.md       # cambios al openapi.yaml vivo de la 001 (0.4.0)
│   ├── summary-cases.md     # casos de SC-002, FR-011 y raciones
│   └── ui-flows.md          # pantallas, estados y mensajes
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── alembic/versions/0004_diary.py                # nuevo
├── src/mykcal/
│   ├── main.py                                   # + router de diary
│   ├── core/errors.py                            # + DIARY_DATE_OUT_OF_RANGE, ENTRY_NOT_FOUND
│   ├── accounts/schemas.py                       # Me + registered_at (R2)
│   ├── accounts/router.py                        # rellena registered_at
│   ├── targets/service.py                        # + target_for_day(session, user_id, day_end_utc)
│   └── diary/                                    # nuevo
│       ├── models.py                             # DiaryEntry
│       ├── schemas.py                            # Meal, DiaryEntryCreate/Update, DiaryEntry, DiaryMeal, DiaryDay
│       ├── day.py                                # day_end_utc(), límites de fecha (R1, R3) — puro
│       ├── quantity.py                           # raciones → g/ml, validación (R6) — puro
│       ├── summary.py                            # valores, totales, redondeo, restante (R10) — puro
│       ├── repository.py                         # consultas; siempre con user_id
│       ├── service.py                            # crear, editar, borrar, restaurar, armar el día
│       └── router.py                             # /v1/diary/**
└── tests/
    ├── conftest.py                               # + fábrica de entradas y de versiones de objetivo
    ├── unit/
    │   ├── test_diary_summary.py                 # S1–S10, M1–M3
    │   ├── test_day_end.py                       # T1–T6
    │   └── test_diary_quantity.py                # Q1–Q7
    ├── integration/
    │   ├── test_diary_entries.py                 # ciclo de vida, restore 60 s, mismo alimento 2 veces
    │   ├── test_diary_day.py                     # objetivo por día, fechas fuera de rango, 5 comidas
    │   └── test_diary_snapshot.py                # SC-004
    ├── contract/test_diary_contract.py
    └── privacy/
        ├── test_user_isolation_diary.py          # nuevo (SC-005)
        ├── test_consent_gate.py                  # + rutas de diary
        ├── test_all_routes_require_identity.py   # cubre las rutas nuevas
        └── test_logs_no_secrets.py               # + nombre, cantidad y fecha

specs/001-acceso-y-despliegue/contracts/openapi.yaml   # 0.4.0: rutas y schemas de api-changes.md

app/
├── lib/
│   ├── core/api/
│   │   ├── models.dart                           # Me.registeredAt, Meal, DiaryEntry, DiaryMeal, DiaryDay, entradas
│   │   └── mykcal_api.dart                       # 5 métodos nuevos (con utc_offset_min)
│   ├── features/
│   │   ├── diary/                                # nuevo
│   │   │   ├── diary_screen.dart                 # cabecera de día + resumen + 5 comidas
│   │   │   ├── diary_day_controller.dart         # AsyncNotifier.family por fecha; aplica cada respuesta
│   │   │   ├── selected_date.dart                # día visible, límites, medianoche (resumed)
│   │   │   ├── local_day.dart                    # fecha local y utc_offset_min al final del día — puro
│   │   │   ├── day_header.dart                   # ‹ › 📅 «Ir a hoy»
│   │   │   ├── summary_card.dart                 # kcal + macros, exceso, incompleto
│   │   │   ├── summary_detail_sheet.dart         # fibra y 7 micros
│   │   │   ├── meal_section.dart                 # cabecera con total, entradas, «+»
│   │   │   ├── entry_quantity_sheet.dart         # añadir y editar; unidad, vista previa, comida, borrar
│   │   │   ├── entry_math.dart                   # misma fórmula y redondeo que el servidor — puro
│   │   │   └── undo_delete.dart                  # SnackBar de 10 s + restore
│   │   ├── home/home_screen.dart                 # cuerpo = DiaryScreen; ⋮ + «Alimentos»
│   │   ├── foods/food_search_screen.dart         # + onSelected (modo selección)
│   │   └── foods/barcode_result_flow.dart        # + modo selección
│   └── l10n/app_es.arb                           # textos nuevos
└── test/diary/                                   # entry_math, local_day, widgets, a11y, navegación, deshacer
```

**Structure Decision**: se mantiene el monorepo.
- **Backend**: un paquete `diary`, como `foods`. Los módulos puros (`day`, `quantity`, `summary`)
  van separados de los que hacen E/S, para probarlos sin base de datos. El objetivo del día se pide
  a `targets/service.py`, que es dueño del historial.
- **App**: una carpeta `features/diary/`. La búsqueda y el escáner de la 003 solo ganan un modo
  selección, para no duplicarlos.

## Complexity Tracking

Sin violaciones que justificar.

## Puntos que Erick debe confirmar

1. **Inicio sin el saludo ni la tarjeta de objetivo** (R13): el diario ocupa Inicio (FR-012).
   El objetivo se abre desde «Ver objetivo» y «Alimentos» pasa al menú ⋮. No bloquea: se
   cambia en `home_screen.dart` si prefieres otra cosa.
2. **Plazo de `restore` en el servidor: 60 s** (R8), frente a los 10 s del aviso, para cubrir la
   red lenta. No bloquea.
