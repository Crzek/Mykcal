# Implementation Plan: Selección dinámica del modelo de Gemini

**Branch**: `010-seleccion-modelo-gemini` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-seleccion-modelo-gemini/spec.md`

## Summary

El backend deja de fijar un modelo de Gemini. Al analizar una foto pregunta a Google qué modelos ve
la clave de la persona, ordena los candidatos (preferencia del operador y, si no, `flash-lite` →
`flash` por versión), y los prueba en orden dentro del mismo presupuesto de 55 s (20 s por
candidato). Un 404, 429, 503 o tiempo agotado pasan al siguiente. El listado se cachea 24 h en
memoria por hash de la clave y los modelos saturados se evitan 3 min. Solo cambia el backend.

- **Selector** (`ai/model_selector.py`): descubrir, filtrar, ordenar, cachear, evitar y reintentar.
  Es lógica pura con reloj inyectable (R1–R6).
- **Proveedor**: `AiProvider` gana `list_models`; `analyze_photo` recibe `model` y `timeout_s`.
  `GeminiProvider` ya no conoce ningún nombre de modelo (R7).
- **Configuración**: `AI_MODEL` pasa a ser una preferencia opcional (lista separada por comas, sin
  valor por defecto) (R8).
- **Registro**: `ai_analysis` añade modelo, origen (`preferred`/`fallback`) e intentos; cada fallo
  intermedio deja `ai_model_attempt` con código y categoría (R9).
- **Avisos**: los de la 006 no cambian. Se añade un único código, `AI_NO_MODEL_AVAILABLE` (503), para
  «ningún modelo compatible» (FR-014) (R10).

## Technical Context

**Language/Version**: Python 3.12 (backend existente)

**Primary Dependencies**: FastAPI, httpx, structlog (ya presentes); ninguna nueva

**Storage**: ninguna tabla ni migración. Caché y modelos evitados en memoria del proceso (spec,
Clarifications)

**Testing**: pytest + `httpx.MockTransport` para Gemini y `FakeProvider` ampliado; sin red real
(principio VI)

**Target Platform**: Linux server (Dokploy), un solo proceso

**Project Type**: web-service (backend de un monorepo; la app Flutter no cambia)

**Performance Goals**: sin penalización perceptible: el listado se pide como mucho una vez por
clave y 24 h (SC-004); un análisis con el primer candidato saturado acaba dentro de 55 s (SC-002)

**Constraints**: total 55 s (`AI_TIMEOUT_S`, sin ampliar), 20 s por candidato, 10 s para el
listado; no registrar claves, fotos, respuestas ni mensajes del proveedor

**Scale/Scope**: ≤ 50 usuarios, un listado de ~50 modelos por clave

## Constitution Check

*GATE: antes de la Fase 0. Se revisa de nuevo tras la Fase 1.*

| Principio | Estado | Nota |
|-----------|--------|------|
| I. La IA propone, el usuario confirma | OK | La respuesta de cualquier modelo pasa por `parse_response`; nada cambia (FR-013) |
| II. Base de alimentos única fuente | OK | `match_items` intacto |
| III. IA opcional / interfaz de proveedor | OK | La selección vive detrás de `AiProvider.list_models`; otros proveedores implementan lo suyo |
| IV. Privacidad | OK | La caché usa el hash de la clave; nunca se escribe en disco ni se registra. Fotos siguen sin guardarse |
| V. Aislamiento por usuario | OK | Caché por hash de clave: nunca se comparte entre claves (FR-008). Sin endpoints nuevos |
| VI. Pruebas sin servicios reales | OK | `FakeProvider` + transporte simulado; reloj inyectable para caducidades |
| VII. Simplicidad | OK | Dos `dict` en memoria. Sin Redis ni tabla (decisión de Clarifications). Sin infraestructura nueva |
| VIII. Accesible, español, métrica | OK | Un mensaje nuevo en español; sin pantallas |
| IX. Entrega vertical | OK con matiz | Mejora de backend sin UI. Se da por cerrada al desplegar y analizar una foto desde el móvil |
| X. Observabilidad sin contenido sensible | OK | Más registro (modelo, categoría, código) y ningún dato sensible; nombres de modelo no lo son |

Sin violaciones: no hay tabla de complejidad.

**Re-evaluación tras la Fase 1**: sin cambios; el diseño no añade piezas ni datos persistentes.

## Project Structure

### Documentation (this feature)

```text
specs/010-seleccion-modelo-gemini/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── provider-and-errors.md
└── tasks.md             # lo genera /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── .env.example                      # AI_MODEL pasa a preferencia opcional
├── src/mykcal/
│   ├── config.py                     # ai_model: str = "" + ai_model_preference
│   ├── main.py                       # crea el ModelSelector en app.state
│   ├── core/errors.py                # + AI_NO_MODEL_AVAILABLE
│   └── ai/
│       ├── provider.py               # + AiModelNotFound, AiNoModelAvailable, ModelInfo, list_models
│       ├── gemini.py                 # list_models; analyze_photo(model, timeout_s); 404 → AiModelNotFound
│       ├── fake.py                   # modelos listables, retirables y saturables
│       ├── model_selector.py         # NUEVO: filtro, orden, caché, evitación, bucle de intentos
│       ├── service.py                # analyze_photo usa el selector; delete_key olvida la caché
│       └── router.py                 # deja de pasar settings.ai_model; pasa el selector a save_key/delete_key
└── tests/
    ├── unit/test_ai_model_selector.py        # NUEVO: filtro/orden/caché/evitación/presupuesto
    ├── integration/test_photo_analysis.py    # casos de retirada, 503, 429 y sin modelo
    ├── privacy/                              # el registro de la feature no filtra datos
    └── test_ai_gemini_validate.py            # + list_models y 404
docs/deploy/produccion.md                     # AI_MODEL descrita como preferencia opcional
```

**Structure Decision**: se amplía el módulo `backend/src/mykcal/ai/` ya existente con un único
fichero nuevo. No hay cambios en la app Flutter ni en la base de datos.

## Complexity Tracking

Sin violaciones que justificar.
