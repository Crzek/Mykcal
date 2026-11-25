# Implementation Plan: Registro rápido (recientes, favoritos y copiar comidas)

**Branch**: `005-registro-rapido` | **Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-registro-rapido/spec.md`

## Summary

Al añadir a una comida, el usuario ve sus 30 últimos alimentos distintos y sus favoritos, y añade
uno con un toque usando la última cantidad. También puede copiar una comida de los 14 días
anteriores a cualquier comida del día visible. Los añadidos rápidos y las copias se deshacen
durante 5 s.

- **Recientes**: consulta sobre `diary_entry`, sin tabla. Toma la última entrada activa de cada
  alimento, descarta los alimentos no disponibles, ordena por `created_at` y corta 30 (R1).
- **Favoritos**: tabla `favorite_food (user_id, food_id)`. Marcar y desmarcar son idempotentes. El
  orden es por último uso y, al final, los nunca usados por nombre (R8).
- **Cantidad sugerida**: la calcula el servidor con una función pura y viaja en `QuickFood`, igual
  para recientes y favoritos (R2).
- **Añadir con un toque**: reutiliza `POST /v1/diary/entries` de la 004, que gana la cabecera
  `Location`. Deshacer = `DELETE` de la 004 (R3, R4).
- **Copiar**: `POST /v1/diary/copies` atómico. Cada copia es una entrada nueva con los valores
  actuales del alimento, o los de la entrada si el alimento ya no existe. Todas comparten un
  `copy_id`, que permite deshacerlas juntas durante 60 s en el servidor (R4–R7).
- **App**: la búsqueda en modo selección gana las pestañas Recientes y Favoritos y una estrella. El
  diario gana «Copiar de otro día» en el menú de cada comida (R12, `contracts/ui-flows.md`).

## Technical Context

**Language/Version**: Python 3.12 (backend); Dart ≥ 3.5 / Flutter ≥ 3.32 (app). Sin cambios.

**Primary Dependencies**: las de la 004, sin añadidos (R14). Backend: FastAPI, SQLAlchemy async,
Alembic. App: Riverpod, dio, intl.

**Storage**: PostgreSQL 16. La migración `0005_quick` crea `favorite_food` y añade
`diary_entry.copy_id` con un índice parcial (`data-model.md`). En el móvil no se guarda nada nuevo.

**Testing**:
- Backend: pytest.
  - Unitarias: `quick/suggest.py`, `quick/ordering.py` y `diary/copy_rules.py` con los casos de
    `contracts/quick-cases.md`.
  - Integración con testcontainers: recientes, favoritos, copia y deshacer (plazo de 60 s con el
    reloj inyectado), cabecera `Location`.
  - Contrato contra `openapi.yaml` 0.5.0.
  - `privacy`: aislamiento (SC-004), consentimiento, identidad y registros.
- App: flutter_test + mocktail. Pestañas y vacíos, «+» con su etiqueta semántica, deshacer de 5 s,
  estrella optimista y hoja de copiar.

**Target Platform**: Android API ≥ 24; contenedor Linux en Dokploy.

**Project Type**: móvil + API (monorepo `backend/` + `app/`).

**Performance Goals**:
- SC-001: un toque desde añadir. Recientes y favoritos llegan en una petición cada uno, < 100 ms
  en el servidor con el índice `(user_id, entry_date)` de la 004.
- SC-002: copiar en < 15 s. La lista llega en una petición (≤ 14 días) y la copia en otra, que
  devuelve el día destino.

**Constraints**:
- Valores solo desde la base: añadir rápido pasa por `create_entry` y la copia vuelve a leer el
  alimento (principio II, FR-006).
- Recientes, favoritos y copias aislados por usuario. `404` indistinguible para lo ajeno
  (principio V, FR-008).
- Sin alimentos, cantidades ni fechas en los registros (principio X, R11).
- Español, métrica, WCAG 2.1 AA, «+» con etiqueta que nombra alimento y cantidad (FR-009).
- Requiere conexión. Sin ella, la hoja de copiar conserva la selección.

**Scale/Scope**: 1 tabla, 1 columna, 7 rutas nuevas y una cabecera, 2 códigos de error; 1 hoja
nueva (copiar) y 4 pantallas modificadas (búsqueda, diario, sección de comida, hoja de entrada).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| I. La IA propone | N/A | Sin IA. Las entradas que cree la 006 contarán como recientes sin cambios aquí. |
| II. Base de alimentos | ✅ | Añadir rápido envía solo `food_id` y cantidad a la ruta de la 004. La copia toma los valores del alimento actual; solo si ya no existe conserva los de la entrada, que también salieron de la base (FR-006, R6). |
| III. IA opcional | ✅ | Recientes y favoritos funcionan sin clave, como pide el principio de forma expresa. |
| IV. Privacidad y salud | ✅ | Las 7 rutas exigen consentimiento (`require_consent`) y se añaden a `test_consent_gate`. No hay fotos. |
| V. Aislamiento y seguridad | ✅ | Todas las consultas filtran por `user_id`. Un alimento ajeno da `404 FOOD_NOT_FOUND`; una copia ajena, `404 COPY_NOT_FOUND`. Prueba `test_user_isolation_quick` sobre las 7 rutas (SC-004). Ninguna ruta pública nueva. |
| VI. Determinista y sin servicios reales | ✅ | La cantidad sugerida, el orden de favoritos, el orden de comidas y los valores de la copia son funciones puras con casos fijos. El plazo de deshacer usa `clock.utcnow`. Ningún servicio externo. |
| VII. Simplicidad | ✅ | Recientes sin tabla ni índice nuevo. Añadir rápido sin ruta propia. Ninguna dependencia ni pieza de infraestructura. La única pieza extra, `copy_id`, evita una ruta de borrado masivo (R4). |
| VIII. Accesible, español, métrica | ✅ | ARB, g/ml/kcal, etiquetas de «+» y estrella con nombre y cantidad, áreas táctiles de 48 dp, cada comida origen se lee entera (`contracts/ui-flows.md`). |
| IX. Entrega vertical | ✅ | Usable en el móvil desde «+». Antes de fusionar: pruebas y escenarios contra el backend local. Se cierra tras desplegar desde `main` y repetir los escenarios 3, 8, 13 y 16 (`quickstart.md` §5). |
| X. Observabilidad | ✅ | Eventos `favorite_added`, `favorite_removed`, `diary_meal_copied` y `diary_copy_undone` con `user_id`, comidas, número de entradas y duración. Se amplía `test_logs_no_secrets` (R11). |
| Ramas y entornos | ✅ | La rama `005-registro-rapido` sale de `dev` con la 004 y volverá a `dev` por PR. |
| Flujo: preguntas abiertas resueltas | ✅ | Las cinco dudas de la spec se cerraron en `/speckit-clarify` (2026-11-24). La discrepancia entre la clarificación 3 y FR-005 se resolvió a favor de FR-005 tras `/speckit-analyze` (punto 1 abajo). |

**Resultado**: pasa sin excepciones.

**Re-check tras el diseño (Phase 1)**: sin cambios.
- El contrato añade 7 rutas autenticadas con consentimiento y ninguna pública. La cabecera
  `Location` es aditiva y no cambia la app de la 004.
- `favorite_food` no guarda datos de salud y su PK impide duplicados.
- `copy_id` es nulo en todas las entradas existentes: la migración no reescribe datos.

## Project Structure

### Documentation (this feature)

```text
specs/005-registro-rapido/
├── plan.md
├── research.md              # R1–R14
├── data-model.md            # favorite_food, diary_entry.copy_id, recientes, QuickFood, copia
├── quickstart.md            # pruebas, migración y 21 escenarios
├── contracts/
│   ├── api-changes.md       # cambios al openapi.yaml vivo de la 001 (0.5.0)
│   ├── quick-cases.md       # casos de cantidad sugerida, órdenes y valores de la copia
│   └── ui-flows.md          # pantallas, estados y mensajes
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── alembic/versions/0005_quick.py                # nuevo
├── src/mykcal/
│   ├── main.py                                   # + router de quick, ANTES que foods (R10)
│   ├── core/errors.py                            # + COPY_SOURCE_EMPTY, COPY_NOT_FOUND
│   ├── quick/                                    # nuevo
│   │   ├── models.py                             # FavoriteFood
│   │   ├── schemas.py                            # QuickFood, QuickFoodList
│   │   ├── suggest.py                            # cantidad sugerida (R2) — puro
│   │   ├── ordering.py                           # orden de favoritos (R8) — puro
│   │   ├── repository.py                         # últimas entradas por alimento, favoritos; siempre con user_id
│   │   ├── service.py                            # recientes, favoritos, marcar, desmarcar
│   │   └── router.py                             # /v1/foods/recent, /v1/foods/favorites/**
│   └── diary/
│       ├── models.py                             # + copy_id
│       ├── schemas.py                            # + DiaryCopyCreate, DiaryCopyResult, CopySource*
│       ├── copy_rules.py                         # ventana de 14 días, orden de comidas, valores (R6, R7) — puro
│       ├── repository.py                         # + entradas de una comida, de un rango, de una copia
│       ├── service.py                            # + copy_meal, undo_copy, copy_sources; create_entry devuelve el id
│       └── router.py                             # + /v1/diary/copy-sources, /v1/diary/copies/**; Location en POST
└── tests/
    ├── conftest.py                               # + fábrica de favoritos
    ├── unit/
    │   ├── test_quick_suggest.py                 # A1–A9
    │   ├── test_quick_ordering.py                # O1–O4
    │   └── test_copy_rules.py                    # C1–C4, V1–V5
    ├── integration/
    │   ├── test_recent_foods.py
    │   ├── test_favorites.py
    │   ├── test_diary_copy.py                    # copia, origen intacto (SC-003), deshacer y plazo
    │   └── test_diary_entries.py                 # + cabecera Location
    ├── contract/test_quick_contract.py           # + orden de routers
    └── privacy/
        ├── test_user_isolation_quick.py          # nuevo (SC-004)
        ├── test_consent_gate.py                  # + 7 rutas
        ├── test_all_routes_require_identity.py   # cubre las rutas nuevas
        └── test_logs_no_secrets.py               # + eventos nuevos

specs/001-acceso-y-despliegue/contracts/openapi.yaml   # 0.5.0: rutas y schemas de api-changes.md

app/
├── lib/
│   ├── core/api/
│   │   ├── models.dart                           # QuickFood, CopySource*, DiaryCopyResult
│   │   └── mykcal_api.dart                       # 7 métodos nuevos; createEntry devuelve también el id (Location)
│   ├── features/
│   │   ├── quick/                                # nuevo
│   │   │   ├── recent_foods_controller.dart      # AsyncNotifier; se invalida al cambiar el diario
│   │   │   ├── favorites_controller.dart         # AsyncNotifier + toggle optimista + favoriteIdsProvider
│   │   │   ├── quick_tabs.dart                   # pestañas Recientes / Favoritos y vacíos
│   │   │   ├── quick_food_tile.dart              # fila con estrella y «+»
│   │   │   └── favorite_star.dart                # estrella reutilizable con su semántica
│   │   ├── diary/
│   │   │   ├── copy_meal_sheet.dart              # nuevo: lista de comidas origen y «Copiar»
│   │   │   ├── undo_snack.dart                   # nuevo: avisos de 5 s
│   │   │   ├── meal_section.dart                 # + menú ⋮ «Copiar de otro día»
│   │   │   └── entry_quantity_sheet.dart         # + estrella en modo editar; cantidad inicial opcional
│   │   └── foods/food_search_screen.dart         # + pestañas con el campo vacío; estrella en resultados
│   └── l10n/app_es.arb                           # textos nuevos
└── test/quick/ y test/diary/                     # pestañas, «+», deshacer, estrella, hoja de copiar, a11y
```

**Structure Decision**: se mantiene el monorepo.
- **Backend**: paquete nuevo `quick` para recientes y favoritos, que son «alimentos para añadir»
  como la búsqueda. La copia va en `diary`, que es dueño de las entradas. Las reglas puras van en
  módulos aparte (`suggest`, `ordering`, `copy_rules`), para probarlas sin base de datos.
- **App**: carpeta `features/quick/` para lo que se ve en la pantalla de añadir. La hoja de copiar
  va en `features/diary/`, porque se abre desde el diario. La búsqueda de la 003 solo gana las
  pestañas y la estrella; no se duplica.

## Complexity Tracking

Sin violaciones que justificar.

## Puntos que Erick debe confirmar

1. **Ventana de copia** (R7) — **resuelto**: 14 días naturales anteriores al día visible,
   omitiendo los vacíos (FR-005). La clarificación 3 de `spec.md` se corrigió para decir lo mismo.
   Si algún día se quieren 14 días *con* registros, solo cambian la consulta de `copy-sources` y
   la validación de `source_date`.
2. **Solo días anteriores** (R5): no se puede copiar una comida de hoy a otra de hoy, porque la
   spec habla de «otro día». No bloquea.
3. **Tras añadir rápido, la pantalla de añadir sigue abierta** (R12), para añadir varios
   alimentos seguidos. El aviso con «Deshacer» se ve en esa pantalla. No bloquea.
4. **Plazo de deshacer la copia en el servidor: 60 s** (R4), frente a los 5 s del aviso, por la red
   lenta, como en la 004. No bloquea.
