# Implementation Plan: Base de alimentos, código de barras y alimentos personalizados

**Branch**: `003-base-de-alimentos` | **Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-base-de-alimentos/spec.md`

## Summary

El usuario puede buscar alimentos genéricos por nombre, escanear o teclear el código de barras de
un envasado y crear sus propios alimentos. La feature termina en encontrar, ver y crear alimentos;
registrarlos en el diario es de la 004.

- **Base genérica**: CIQUAL (ANSES, Licence Ouverte) en lugar de BEDCA, cuya licencia exige
  autorización para este uso. Erick lo decidió el 2026-11-24 y con ello se cierra la pregunta
  abierta 6. Se versiona una semilla de unos 600 alimentos traducidos y con sinónimos, generada
  con un script, y se importa al arrancar de forma idempotente (R1–R4).
- **Modelo**: una sola tabla `food` con `kind` `generic | packaged | custom`. Los nutrientes
  admiten `NULL`, que significa «sin dato» (R5, `data-model.md`).
- **Búsqueda**: texto normalizado en Python (sin tildes) + `pg_trgm`, con orden personalizados →
  genéricos → envasados y límite de 20. SC-001 se mide con 50 casos fijos (R6,
  `contracts/search-cases.md`).
- **Código de barras**: personalizado propio → copia local de 30 días → Open Food Facts por
  `httpx`. Si OFF falla, se sirve la copia caducada. En las pruebas se usan siempre *fixtures* (R7–R9).
- **Personalizados**: entrada por 100 o por ración, convertida a 100 en el servidor, con validación
  dura y aviso de kcal. Se eliminan con borrado lógico (R10, R11).
- **App**: búsqueda, detalle, escáner con `mobile_scanner`, formulario, «Mis alimentos» y «Fuentes
  de datos» (R13, `contracts/ui-flows.md`).

## Technical Context

**Language/Version**: Python 3.12 (backend); Dart ≥ 3.5 / Flutter ≥ 3.32 (app). Sin cambios.

**Primary Dependencies**:
- Backend: las de la 002, sin añadidos (`httpx` ya está). Extensión `pg_trgm` de PostgreSQL.
- App: `mobile_scanner` ^7 (R13, R17).

**Storage**: PostgreSQL 16. La migración `0003_foods` crea `pg_trgm`, `food` y `food_import`
(`data-model.md`). La semilla `generic_foods.csv` va en la imagen. En el móvil no se guarda nada
nuevo.

**Testing**:
- Backend: pytest.
  - Unitarias: `normalize`, conversión de OFF, GTIN, validación de personalizados,
    `sum_nutrients` y lectura de CIQUAL.
  - Integración con testcontainers: importación, búsqueda con SC-001, código de barras con OFF
    simulado y CRUD.
  - Contrato contra `openapi.yaml`, ampliado según `contracts/api-changes.md`.
  - `privacy`: aislamiento de personalizados, consentimiento y registros.
  - Guarda de red para OFF (FR-018).
- App: flutter_test + mocktail.
  - Widgets y accesibilidad de las 6 pantallas nuevas.
  - Prueba pura de `custom_food_check.dart`.
  - Escáner con el controlador simulado.

**Target Platform**: Android API ≥ 24 con cámara opcional; contenedor Linux en Dokploy.

**Project Type**: móvil + API (monorepo `backend/` + `app/`).

**Performance Goals**:
- SC-002: un código ya consultado responde en menos de 2 s; es una consulta por índice único.
- La búsqueda responde en menos de 300 ms en el servidor, con índice GIN sobre unas pocas miles
  de filas.

**Constraints**:
- Las pruebas nunca llaman a Open Food Facts (FR-018, principio VI).
- Personalizados aislados por usuario: `404` para los ajenos (principio V).
- Sin consultas ni códigos de barras en los registros (principio X, R15).
- Valores nutricionales solo desde la base de alimentos (principio II).
- Textos en ARB, formato numérico español, unidades métricas y WCAG 2.1 AA (FR-017).

**Scale/Scope**: 2 tablas, 7 rutas, unos 600 alimentos genéricos, 6 pantallas nuevas y 2
modificadas (Inicio y Ajustes).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| I. La IA propone | N/A | Sin IA. |
| II. Base de alimentos | ✅ | Esta feature construye la única fuente nutricional: genéricos (CIQUAL), envasados (OFF) y personalizados. La 006 cruzará contra `food`. |
| III. IA opcional | ✅ | Búsqueda, escáner y personalizados funcionan sin clave de IA. |
| IV. Privacidad y salud | ✅ | Todas las rutas `/v1/foods/**` exigen consentimiento y se añaden a la prueba `test_consent_gate` (R14). El escáner no guarda imágenes: solo lee el código en el móvil. |
| V. Aislamiento y seguridad | ✅ | Rutas tras `require_consent`. El repositorio de personalizados siempre recibe `user_id`. Un personalizado ajeno da `404` indistinguible. Prueba `privacy` de SC-004 sobre las 7 rutas. Ninguna ruta pública nueva. |
| VI. Determinista y sin servicios reales | ✅ | Conversiones y validaciones puras con `Decimal`. OFF con transporte inyectable y *fixtures*, y una guarda que falla si se crea un cliente real (R7, R18). La semilla genérica está versionada y la importación es idempotente. |
| VII. Simplicidad | ✅ | Sin motor de búsqueda ni caché externa: PostgreSQL + `pg_trgm`. Una tabla para los tres tipos. Una dependencia nueva en la app, justificada (R17). Sin caché de códigos no encontrados ni paquetes para abrir ajustes o enlaces. |
| VIII. Accesible, español, métrica | ✅ | Nombres en español (traducción curada), ARB, g/ml/kcal, «sin dato» textual, avisos con icono y texto en `liveRegion` (`contracts/ui-flows.md`). |
| IX. Entrega vertical | ✅ | Usable en el móvil desde Inicio → Alimentos. Antes de fusionar: pruebas y escenarios contra el backend local. Se cierra tras desplegar desde `main` y repetir los escenarios clave en el móvil (`quickstart.md` §5). |
| X. Observabilidad | ✅ | Eventos `food_search`, `barcode_lookup`, `custom_food_*` y `generic_import_*` sin consulta, sin código y sin valores. La consulta y el código van en el *query string*, que no se registra. Prueba en `test_logs_no_secrets` (R15). |
| Ramas y entornos | ✅ | La rama sale de `origin/dev` (que ya incluye la 001, la 002 y la 008) y volverá a `dev` por PR. |
| Flujo: preguntas abiertas resueltas | ✅ | Pregunta 6 (licencia de BEDCA) cerrada con CIQUAL (R1). |

**Resultado**: pasa sin excepciones.

**Re-check tras el diseño (Phase 1)**: sin cambios. El contrato añade 7 rutas autenticadas con
consentimiento y ninguna pública. `data-model.md` restringe los personalizados por dueño con
`CHECK` e índices parciales. La 004 hereda el compromiso de copiar los valores en cada entrada
(FR-015).

## Project Structure

### Documentation (this feature)

```text
specs/003-base-de-alimentos/
├── plan.md
├── research.md              # R1–R18
├── data-model.md            # food, food_import, ciclo de vida, reglas de acceso
├── quickstart.md            # semilla, pruebas, migración y 20 escenarios
├── contracts/
│   ├── api-changes.md       # cambios al openapi.yaml vivo de la 001
│   ├── search-cases.md      # 50 casos de SC-001
│   └── ui-flows.md          # pantallas, estados y mensajes
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── data/ciqual/ciqual_es.csv                     # nuevo: selección + traducción + sinónimos (curado)
├── scripts/build_generic_seed.py                 # nuevo: CIQUAL oficial + CSV curado → semilla (R2, R3)
├── docker-entrypoint.sh                          # + python -m mykcal.foods.load_generic
├── alembic/versions/0003_foods.py                # nuevo
├── src/mykcal/
│   ├── main.py                                   # router de foods, off_transport
│   ├── config.py                                 # + off_base_url, off_user_agent, off_timeout_s
│   ├── core/errors.py                            # + FOOD_NOT_FOUND, FOOD_BARCODE_TAKEN, FOOD_SOURCE_UNAVAILABLE
│   └── foods/                                    # nuevo
│       ├── data/generic_foods.csv                # semilla generada y versionada
│       ├── data/FUENTES.md                       # atribución CIQUAL y OFF (R16)
│       ├── models.py                             # Food, FoodImport
│       ├── schemas.py                            # Nutrients, FoodSummary, Food, BarcodeLookup, CustomFood*
│       ├── nutrients.py                          # nombres, máximos y sum_nutrients (R12)
│       ├── text.py                               # normalize() (R6)
│       ├── gtin.py                               # validación y paso UPC-A → EAN-13 (R9)
│       ├── off_client.py                         # cliente y conversión de OFF (R7, R8)
│       ├── custom_rules.py                       # conversión por ración, validación y KCAL_MISMATCH (R10)
│       ├── repository.py                         # consultas; personalizados siempre con user_id
│       ├── service.py                            # búsqueda, código de barras (R9) y CRUD
│       ├── router.py                             # /v1/foods/**
│       ├── ciqual.py                             # lectura de CIQUAL, curado y semilla (R2, R3)
│       └── load_generic.py                       # importación idempotente con bloqueo (R4)
└── tests/
    ├── fixtures/off/*.json                       # respuestas guardadas de OFF
    ├── conftest.py                               # + guarda de red de OFF, usuario con consentimiento
    ├── unit/
    │   ├── test_food_text.py
    │   ├── test_gtin.py
    │   ├── test_off_mapping.py
    │   ├── test_custom_rules.py
    │   ├── test_sum_nutrients.py
    │   └── test_ciqual_cells.py
    ├── integration/
    │   ├── test_generic_import.py
    │   ├── test_search_cases.py                  # SC-001
    │   ├── test_search_order.py
    │   ├── test_barcode_lookup.py
    │   └── test_custom_foods.py
    ├── contract/test_foods_contract.py
    └── privacy/
        ├── test_consent_gate.py                  # + rutas de foods
        ├── test_user_isolation_foods.py          # nuevo (SC-004)
        ├── test_all_routes_require_identity.py   # cubre las rutas nuevas
        └── test_logs_no_secrets.py               # + consulta y código

specs/001-acceso-y-despliegue/contracts/openapi.yaml   # 0.3.0: rutas y schemas de api-changes.md

app/
├── android/app/src/main/AndroidManifest.xml      # + CAMERA, uses-feature camera required=false
├── pubspec.yaml                                  # + mobile_scanner
├── lib/
│   ├── core/api/
│   │   ├── models.dart                           # Nutrients, FoodSummary, Food, BarcodeLookup, CustomFoodInput…
│   │   └── mykcal_api.dart                       # 7 métodos nuevos
│   ├── features/
│   │   ├── foods/                                # nuevo
│   │   │   ├── food_search_screen.dart           # + controlador con debounce y descarte de respuestas viejas
│   │   │   ├── food_detail_screen.dart
│   │   │   ├── nutrient_format.dart              # «sin dato», unidades, por 100 g/ml
│   │   │   ├── barcode_scan_screen.dart          # mobile_scanner, permisos
│   │   │   ├── barcode_manual_dialog.dart
│   │   │   ├── gtin.dart                         # mismo algoritmo que el backend
│   │   │   ├── custom_food_form_screen.dart
│   │   │   ├── custom_food_check.dart            # validación + KCAL_MISMATCH (pura)
│   │   │   └── my_foods_screen.dart
│   │   ├── settings/data_sources_screen.dart     # nuevo (R16)
│   │   ├── settings/settings_screen.dart         # + «Fuentes de datos»
│   │   └── home/home_screen.dart                 # + «Alimentos»
│   └── l10n/app_es.arb                           # textos nuevos
└── test/foods/                                   # widgets, a11y, custom_food_check, gtin, escáner simulado
```

**Structure Decision**: se mantiene el monorepo. En el backend, todo lo de alimentos va en un
paquete `foods`, como `profile` y `targets`, con los módulos puros (`text`, `gtin`,
`custom_rules`, `nutrients`, conversión de OFF) separados de los que hacen E/S para probarlos sin
base de datos. Los datos de origen curados (`backend/data/`) quedan fuera del paquete. La semilla
generada va dentro, para que entre en la imagen. En la app, una carpeta `features/foods/` que la
004 importará.

## Complexity Tracking

Sin violaciones que justificar.

## Puntos que Erick debe confirmar o hacer

1. **Licencia de CIQUAL 2025** (R1) — *pendiente*: Zenodo (registro 17550133) la publica bajo
   CC BY 4.0, que exige citar la fuente (hecho en «Fuentes de datos» y `FUENTES.md`). Erick
   confirma en la ficha de la fuente que sigue siendo así.
2. **Revisar la selección y la traducción** de `ciqual_es.csv` — *hecho* (2026-11-24): son
   359 alimentos, no los ~600 previstos; cubren los 50 casos de SC-001 (50/50). Mejoras
   opcionales para una spec futura: aceite de oliva refinado, bebidas vegetales distintas de
   la de soja y retirar «Verdura cocinada (promedio)».
3. **`OFF_USER_AGENT` en Dokploy** (R7) — *pendiente*: el valor por defecto no lleva datos de
   contacto. Open Food Facts recomienda incluir uno; Erick decide si lo añade en la variable
   de entorno. No bloquea.
4. **Constitución** — *hecho* (1.2.1, fusionada en `main`): la restricción técnica «Alimentos»
   ya dice CIQUAL traducida. La spec no cambia, porque su supuesto ya contemplaba otra base.
