# Implementation Plan: Peso y recálculo del objetivo

**Branch**: `007-peso-y-recalculo` | **Date**: 2026-11-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-peso-y-recalculo/spec.md`

## Summary

Épica E9: el usuario registra su peso diario (un registro por día, 30–300 kg, hasta hoy en la fecha
local del móvil), ve su evolución en una gráfica con media móvil de 7 días y periodos 30/90/todo, y
recibe una propuesta de recálculo del objetivo cuando la media semanal difiere más de un 2% del peso
usado en el último cálculo. La propuesta se guarda en el servidor: queda pendiente y se vuelve a
mostrar en cada apertura hasta que el usuario acepte (recalcula con las reglas de 002 usando la media
semanal como peso) o ignore (no se repite durante 7 días).

Enfoque técnico: reutilizar la tabla `weight_entry` y el campo `daily_target.calc_weight_kg` ya
creados en 002. Añadir un módulo `mykcal/weight/` con endpoints CRUD de peso, gráfica y propuesta de
recálculo; un módulo de cálculo puro (`average.py`) para la media móvil y el umbral; y una tabla
nueva `recalc_proposal` para persistir la propuesta y su respuesta. En Flutter, una feature `weight`
con pantalla de registro, gráfica accesible y el diálogo de propuesta, enlazada al arranque de la app.

## Technical Context

**Language/Version**: Python 3.12 (backend), Dart/Flutter 3.x (app)

**Primary Dependencies**: FastAPI, SQLAlchemy 2 (async), Alembic, Pydantic v2, structlog (backend);
Flutter, Riverpod, `fl_chart` para la gráfica (app)

**Storage**: PostgreSQL. Tablas reutilizadas `weight_entry` y `daily_target` (002); tabla nueva
`recalc_proposal`. Migración Alembic `0006`.

**Testing**: pytest (unit/integration/contract) en backend con fixtures, sin servicios reales;
`flutter test` en la app. Pruebas de contrato contra
`specs/001-acceso-y-despliegue/contracts/openapi.yaml`.

**Target Platform**: Android (APK por enlace) + backend en Dokploy (producción desde `main`).

**Project Type**: Mobile + API (monorepo `app/` + `backend/`).

**Performance Goals**: hasta 50 usuarios (principio VII); registrar peso en <10 s (SC-001). Sin
piezas de infraestructura nuevas.

**Constraints**: offline avisa y conserva lo escrito; cálculo determinista y probado (principio VI);
WCAG 2.1 AA, español, kg (principio VIII). La fecha «hoy» la determina el móvil (fecha local); el
backend valida con un día de margen por zona horaria, como el diario (`diary/day.py`).

**Scale/Scope**: 1 pantalla de peso con gráfica + 1 diálogo de propuesta; ~5 endpoints nuevos; 1
tabla nueva; 1 módulo de cálculo puro.

## Constitution Check

*GATE: pasa antes de Phase 0 y se re-evalúa tras Phase 1.*

| Principio | Cómo lo cumple esta feature |
|---|---|
| I. La IA propone, el usuario confirma | La propuesta de recálculo no cambia el objetivo sin que el usuario acepte; un objetivo editado a mano avisa de que se sustituirán sus valores (FR-008). No interviene IA. |
| II. Base de alimentos única fuente | No aplica (sin nutrición directa); el recálculo reutiliza `targets/calc.py`. |
| III. IA opcional | El peso y el recálculo funcionan sin clave de IA. |
| IV. Privacidad y datos de salud | El peso es dato de salud: todos los endpoints exigen consentimiento (`require_consent`). No hay fotos ni claves. Los registros (peso, propuesta) no van a los logs (principio X). |
| V. Aislamiento por usuario | Todo filtra por `principal.account.id`; el usuario solo ve y modifica su propio peso (FR-010). Prueba de aislamiento en `tests/privacy`. |
| VI. Cálculos deterministas y pruebas sin servicios | `weight/average.py` es puro (media móvil, redondeo HALF_UP a 1 decimal, umbral 2%) y cubierto por casos conocidos (FR-009, SC-002). El recálculo usa `targets/calc.py` ya determinista. |
| VII. Simplicidad | Sin colas ni cachés; se reutiliza `weight_entry` y el motor de cálculo de 002. Una sola tabla nueva. |
| VIII. Accesible, español, métrica | Gráfica con alternativa textual (resumen + lista), textos externalizados en `l10n`, kg, tema claro/oscuro. |
| IX. Entrega vertical | Entregable usable en el móvil: registrar peso, ver gráfica, aceptar/ignorar recálculo. |
| X. Observabilidad sin contenido sensible | Logs con usuario/acción (`weight_saved`, `recalc_proposed`, `recalc_accepted`) sin valores de peso. |

**Resultado**: PASS. Sin violaciones; `Complexity Tracking` vacío.

## Project Structure

### Documentation (this feature)

```text
specs/007-peso-y-recalculo/
├── plan.md              # Este archivo
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/           # Phase 1 (api-changes.md, average-cases.md, ui-flows.md)
└── tasks.md             # Phase 2 (/speckit-tasks, NO lo crea /speckit-plan)
```

### Source Code (repository root)

```text
backend/
├── src/mykcal/
│   ├── weight/                 # NUEVO módulo
│   │   ├── __init__.py
│   │   ├── average.py          # puro: media móvil 7d, redondeo, umbral 2%, serie de gráfica
│   │   ├── models.py           # RecalcProposal (WeightEntry sigue en profile/models.py)
│   │   ├── schemas.py          # WeightEntry(IO), WeightList, WeightChart, RecalcProposal
│   │   ├── service.py          # CRUD de peso, gráfica, generar/aceptar/ignorar propuesta
│   │   └── router.py           # /v1/weight*, /v1/recalc-proposal*
│   ├── profile/models.py       # WeightEntry (ya existe, reutilizado)
│   ├── targets/service.py      # recalculate/current_target (reutilizados)
│   └── main.py                 # registra weight_router
├── alembic/versions/
│   └── 0006_weight_recalc.py   # NUEVO: tabla recalc_proposal (+ índices)
└── tests/
    ├── unit/test_weight_average.py        # NUEVO (FR-009, SC-002)
    ├── integration/test_weight_entries.py # NUEVO (CRUD, FR-001/002)
    ├── integration/test_recalc_proposal.py# NUEVO (FR-005–008, persistencia)
    ├── contract/test_weight_contract.py   # NUEVO
    └── privacy/                           # añade peso al aislamiento por usuario

app/
└── lib/
    ├── features/weight/        # NUEVO
    │   ├── weight_controller.dart     # Riverpod: lista, alta/edición/borrado
    │   ├── weight_screen.dart         # registro + lista de pesos
    │   ├── weight_chart.dart          # gráfica (fl_chart) + alternativa textual
    │   └── recalc_proposal_dialog.dart# propuesta pendiente (acepta/ignora)
    ├── features/target/recalc_dialogs.dart  # se reutiliza/extiende
    ├── core/api/mykcal_api.dart       # métodos nuevos de peso y propuesta
    ├── core/api/models.dart           # modelos de peso/gráfica/propuesta
    └── l10n/app_es.arb                # textos nuevos
```

**Structure Decision**: Mobile + API en monorepo (igual que 001–006). Se añade un módulo backend
`weight` cohesionado y una feature Flutter `weight`. Se reutilizan `weight_entry`, `daily_target` y
el motor `targets/calc.py` de 002 para no duplicar reglas (principio VII).

## Complexity Tracking

> Sin violaciones de la constitución. Tabla vacía.
