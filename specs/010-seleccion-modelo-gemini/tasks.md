# Tasks: Selección dinámica del modelo de Gemini

**Input**: Design documents from `specs/010-seleccion-modelo-gemini/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R10), data-model.md, contracts/`provider-and-errors.md`, quickstart.md

**Tests**: se incluyen (principio VI y práctica de la 001–009). Los de cada historia se escriben antes y deben fallar. Ninguna prueba llama a Gemini: usan `FakeProvider` y `httpx.MockTransport`.

**Organization**: por historia de usuario. Todo es backend; no hay cambios en la app Flutter ni migraciones. US1 y US2 comparten el selector (se construye en US1 y US2 añade el reintento). US3 añade la preferencia. US4 solo se protege con una prueba (ya está hecho en código). US5 completa el registro.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: US1 modelo retirado, US2 saturación y cuota, US3 preferencia, US4 guardar clave, US5 diagnóstico
- Rutas de backend relativas a `backend/src/mykcal/` salvo `backend/tests/`, `backend/.env.example` o `docs/`.
- Comandos: `cd backend && uv run ruff check && uv run pytest`.

---

## Phase 1: Setup

- [X] T001 Comprobar que la rama es `010-seleccion-modelo-gemini` y que `cd backend && uv run ruff check && uv run pytest` pasa antes de empezar. El árbol ya trae cambios sin confirmar (`ai/gemini.py`, `config.py`, `backend/.env.example`, `docs/deploy/produccion.md`, `backend/tests/test_ai_gemini_validate.py`): son la corrección previa de `validate_key` (spec, Assumptions) y se conservan

---

## Phase 2: Foundational (bloquea todas las historias)

**Purpose**: contrato nuevo del proveedor, errores y registro. Sin esto no se puede escribir el selector.

- [X] T002 En `ai/provider.py` añadir: `@dataclass(frozen=True) class ModelInfo` con `name: str` (sin prefijo `models/`) y `generate_content: bool`; excepciones `AiModelNotFound(Exception)` y `AiNoModelAvailable(Exception)`; en `AiProviderUnavailable` un atributo `overloaded: bool = False` (constructor `__init__(self, overloaded: bool = False)`). Cambiar la ABC `AiProvider`: nuevo `async def list_models(self, raw_key: str, timeout_s: float) -> list[ModelInfo]` y `analyze_photo(self, raw_key: str, model: str, image: bytes, prompt: str, timeout_s: float) -> str`. `validate_key` no cambia (`contracts/provider-and-errors.md` §2)
- [X] T003 [P] En `core/errors.py` añadir `ErrorCode.AI_NO_MODEL_AVAILABLE = "AI_NO_MODEL_AVAILABLE"` (503) junto a los demás `AI_*`
- [X] T004 [P] En `logging.py` añadir a `ALLOWED_FIELDS` los campos `"model"`, `"selection"`, `"attempts"` y `"category"` (`"status"`, `"result"` y `"error_class"` ya existen). Nunca se añade un campo de texto libre (research R9)
- [X] T005 En `config.py` sustituir `ai_model: str = "gemini-3.6-flash"` por `ai_model: str = ""` y añadir una propiedad `ai_model_preference -> list[str]` que parta por comas, recorte espacios, descarte vacíos y duplicados conservando el orden (research R8). Mantener `ai_timeout_s` igual (de 5 a 58, 55 por defecto)
- [X] T006 En `ai/fake.py` reescribir `FakeProvider` para el contrato nuevo, conservando `validate_outcome` y la forma de `calls: list[tuple[str, int, str]]` `(raw_key, len(image), prompt)` que ya usan las pruebas de la 006. Añadir: `models: list[str]` (por defecto `["gemini-3.6-flash"]`), `list_outcome: Literal["ok","unavailable","key_invalid"]`, `model_outcomes: dict[str, str]` (por nombre: `"ok"`, `"not_found"`, `"overloaded"`, `"quota"`, `"timeout"`; ausente = el `analyze_outcome` global de siempre), `list_calls: int` y `models_tried: list[str]`. `list_models` devuelve `ModelInfo(name, True)` por cada nombre en `models`. `analyze_photo` anota `models_tried` y respeta `model_outcomes[model]` (`"overloaded"` lanza `AiProviderUnavailable(overloaded=True)`; `"not_found"` lanza `AiModelNotFound`)
- [X] T007 En `ai/gemini.py` adaptar `GeminiProvider` al contrato (`GeminiProvider()` sin argumentos): `_post(raw_key, url, body, timeout)` recibe la URL y `analyze_photo(raw_key, model, image, prompt, timeout_s)` usa `f"{BASE_URL}/{model}:generateContent"`; **404 → `AiModelNotFound`**, **503 → `AiProviderUnavailable(overloaded=True)`**, el resto como hoy (400/401/403 → `AiKeyInvalid`, 429 → `AiQuotaExceeded`, otros → `AiProviderUnavailable`). Añadir `list_models(raw_key, timeout_s)`: `GET BASE_URL` con `params={"pageSize": 1000}` y cabecera `x-goog-api-key`, seguir `nextPageToken` hasta 3 páginas, quitar el prefijo `models/` de `name`, marcar `generate_content = "generateContent" in supportedGenerationMethods`; mismos mapeos de error y mismo registro (solo `status` y `_google_status`, nunca el cuerpo). Actualizar las llamadas `GeminiProvider("gemini-x", 5)` de `backend/tests/test_ai_gemini_validate.py` a `GeminiProvider()`

**Checkpoint**: la suite no vuelve a estar en verde hasta terminar US1: el cambio de firma de `AiProvider` (T002, T006, T007) rompe `main.py` y `service.py` hasta T008 y T013. Se trabaja Phase 2 + US1 como un bloque.

---

## Phase 3: User Story 1 — El análisis sigue funcionando cuando un modelo desaparece (P1) 🎯 MVP

**Goal**: elegir modelo en tiempo de ejecución a partir del listado de la clave y analizar con él (FR-001, FR-002, FR-005, FR-006, FR-007, FR-008).

**Independent Test**: con `FakeProvider.models` sin el modelo preferido, `POST /v1/photo-analysis` devuelve 200 con otro modelo y el registro dice `selection=fallback`.

### Tests (escribir primero, deben fallar)

- [X] T009 [P] [US1] Crear `backend/tests/unit/test_ai_model_selector.py` (parte pura, sin red). Funciones `is_economic(name)` y `rank(models)`:
  - acepta `gemini-3.6-flash`, `gemini-3.6-flash-lite`, `gemini-flash-latest`; rechaza `gemini-3.6-pro`, `gemini-2.0-flash-exp`, `gemini-3.6-flash-tts`, `gemini-3.6-flash-image`, `gemini-live-flash`, `text-embedding-004`, `gemma-3-27b-it`
  - orden: todos los `flash-lite` antes que los `flash`; dentro de cada grupo, versión descendente (`3.6` antes que `3.5` antes que `2.0`; compara números, no texto: `3.10` > `3.9`); los alias sin versión (`gemini-flash-latest`) al final de su grupo; empate por nombre inverso
  - descarta los modelos con `generate_content=False`
- [X] T010 [P] [US1] En el mismo fichero, parte del selector con `FakeProvider` y reloj falso:
  - sin preferencia, con listado `[gemini-3.5-flash, gemini-3.6-flash-lite]`, el primer intento es `gemini-3.6-flash-lite` y `selection == "fallback"`
  - un solo `list_models` en dos ejecuciones seguidas con la misma clave (`list_calls == 1`, FR-007, SC-004)
  - con el reloj +24 h vuelve a listar (`list_calls == 2`)
  - dos claves distintas → dos listados y catálogos separados (FR-008); el hash de la clave no aparece en ningún `repr` del selector
  - el listado falla pero hay catálogo viejo → se usa el viejo; sin catálogo y sin preferencia → `AiProviderUnavailable`; sin catálogo y con preferencia → se intenta la preferencia tal cual (research R6)
  - listado sin ningún modelo compatible → `AiNoModelAvailable`
  - `forget(raw_key)` borra su catálogo
- [X] T011 [P] [US1] En `backend/tests/integration/test_photo_analysis.py` añadir: (a) `ai.models = ["gemini-3.6-flash"]` sin preferencia → 200 y `ai.models_tried == ["gemini-3.6-flash"]`; (b) settings con `ai_model="gemini-1.0-flash"` (retirado, no está en el listado) → 200 con otro modelo y evento `ai_analysis` con `selection="fallback"`; (c) listado sin modelos compatibles (`ai.models = ["gemini-3.6-pro"]`) → `503 AI_NO_MODEL_AVAILABLE` y evento `ai_analysis` con `result="no_model"`; (d) el 404 a mitad (`ai.model_outcomes["gemini-3.6-flash"]="not_found"` con un segundo modelo en la lista) → 200 con el segundo y un segundo `list_models` (`ai.list_calls == 2`)

### Implementation

- [X] T012 [US1] Crear `ai/model_selector.py` con las funciones puras `is_economic(name)` y `rank(models)` (reglas de research R2, verbatim de T009) y la clase `ModelSelector(provider, preference, clock=time.monotonic)`:
  - constantes `CATALOG_TTL_S = 86400`, `COOLDOWN_S = 180`, `PER_MODEL_TIMEOUT_S = 20`, `LIST_TIMEOUT_S = 10`
  - `_catalog: dict[str, tuple[float, list[ModelInfo]]]` indexado por `sha256(raw_key).hexdigest()`; `asyncio.Lock` por hash para un solo vuelo; poda de entradas caducadas hace más de 24 h al guardar
  - `async def run(user_id, raw_key, total_timeout_s, attempt) -> SelectionOutcome` donde `attempt: Callable[[str, float], Awaitable[str]]`; `SelectionOutcome` (dataclass) con `text`, `model`, `selection` (`"preferred"` | `"fallback"`) y `attempts: int`
  - candidatos = preferencia que esté en el catálogo (sin filtrar por nombre) + `rank` del catálogo sin repetidos; `selection="preferred"` solo si el elegido es de la preferencia
  - listado: caché → si caduca, pedir con `min(LIST_TIMEOUT_S, restante)`; si falla, catálogo viejo; sin catálogo, preferencia tal cual; si no hay nada, relanzar `AiProviderUnavailable`; `AiKeyInvalid` siempre se propaga
  - sin candidatos → `AiNoModelAvailable`
  - `forget(raw_key)`
  - Este bucle en esta tarea solo cubre éxito y 404 (quitar del catálogo y refrescar el listado **una vez** por ejecución, research R5); los reintentos por 503/429/tiempo los añade T016
- [X] T008 [US1] En `main.py` sustituir `GeminiProvider(settings.ai_model, settings.ai_timeout_s)` por `GeminiProvider()`, y crear `app.state.model_selector = ModelSelector(app.state.ai_provider, settings.ai_model_preference)` (la clase se crea en T012)
- [X] T013 [US1] En `ai/service.py::analyze_photo` quitar el parámetro `model` y recibir `selector: ModelSelector` y `timeout_s: float`; llamar a `selector.run(user_id, raw_key, timeout_s, attempt)` con `attempt = lambda model, t: ai_provider.analyze_photo(raw_key, model, photo, prompt, t)` (el `prompt` se construye una vez). Añadir `AiNoModelAvailable` a `_FAILURES` → `("no_model", 503, ErrorCode.AI_NO_MODEL_AVAILABLE, "No hay ningún modelo de IA disponible para tu clave. Puedes continuar a mano.")`. El evento `ai_analysis` pasa a llevar `model`, `selection` y `attempts` del `SelectionOutcome`; en fallo, `model` es el último intentado si lo hubo: `ModelSelector.run` (que ya recibe `user_id`) fija `last_model` y `attempts` como atributos de la excepción que relanza (`exc.last_model`, `exc.attempts`), sin guardar estado compartido entre peticiones; el servicio los lee con `getattr(exc, "last_model", None)`
- [X] T014 [US1] En `ai/router.py::photo_analysis` dejar de pasar `settings.ai_model`; pasar `request.app.state.model_selector` y `settings.ai_timeout_s`
- [X] T015 [US1] En `ai/service.py::delete_key` descifrar la clave guardada antes de borrar y llamar a `selector.forget(raw_key)`; `save_key` hace lo mismo con la clave anterior si existía (la clave cambiada deja de usar su catálogo, spec: edge case). Recibir el selector desde el router (`ai/router.py`) y ajustar las llamadas. Pruebas en `backend/tests/integration/test_ai_key.py`: (a) tras `DELETE /v1/ai-key` y un `PUT` con la misma clave, el siguiente análisis vuelve a listar (`ai.list_calls` +1); (b) tras un `PUT` con una clave distinta, el análisis lista de nuevo con la clave nueva

**Checkpoint**: US1 funciona y se puede probar sola; los tests de la 006 siguen en verde.

---

## Phase 4: User Story 2 — Una saturación o un límite temporal no impiden analizar (P1)

**Goal**: probar el siguiente candidato ante 503, 429 o tiempo agotado dentro de los 55 s, y no insistir 3 minutos en un modelo saturado (FR-003, FR-009).

**Independent Test**: `model_outcomes={"gemini-3.6-flash-lite": "overloaded"}` con un segundo modelo OK → 200 con el segundo y 2 intentos.

### Tests (escribir primero, deben fallar)

- [X] T016 [P] [US2] Ampliar `backend/tests/unit/test_ai_model_selector.py` (reloj falso, `FakeProvider`):
  - 503 en el 1.º y OK en el 2.º → resultado del 2.º, `attempts == 2`
  - 429 en el 1.º y OK en el 2.º → resultado del 2.º
  - tiempo agotado en el 1.º y OK en el 2.º → resultado del 2.º
  - tras un 503, una segunda ejecución a los 60 s no llama al saturado (`models_tried` sin él); a los 181 s vuelve a llamarlo (`COOLDOWN_S = 180`)
  - un 429 **no** inicia evitación
  - si el único candidato restante está en evitación, se intenta igualmente
  - el timeout pasado a cada intento es `min(20, restante)`; con 45 s ya gastados y 3 modelos, el último recibe ≤ 10 s; con < 1 s restante se corta sin llamar
  - todos 503 → `AiProviderUnavailable`; todos 429 → `AiQuotaExceeded`; mezcla de 429 y 503 → `AiQuotaExceeded`; 429 + tiempo agotado → `AiQuotaExceeded`; solo tiempos agotados → `AiTimeout`
  - `AiKeyInvalid` en cualquier intento detiene el bucle sin probar más
- [X] T017 [P] [US2] En `backend/tests/integration/test_photo_analysis.py`: (a) 1.º `overloaded`, 2.º OK → 200 y `ai.models_tried` con los dos; (b) 1.º `quota`, 2.º OK → 200; (c) todos `overloaded` → `503 AI_PROVIDER_UNAVAILABLE`; (d) todos `quota` → `429 AI_QUOTA_EXCEEDED`; (e) todos `timeout` → `504 AI_TIMEOUT`; (f) una respuesta inválida (`analyze_outcome="invalid_json"`) con dos modelos disponibles → `422 AI_RESPONSE_INVALID` y **un solo** modelo probado (research R5)

### Implementation

- [X] T018 [US2] En `ai/model_selector.py::run` completar el bucle: `deadline = clock() + total_timeout_s`; por candidato `timeout = min(PER_MODEL_TIMEOUT_S, deadline - clock())`, cortar si queda < 1 s; `AiProviderUnavailable(overloaded=True)` → `_cooldown[(hash, model)] = clock() + COOLDOWN_S` y siguiente; otros `AiProviderUnavailable`, `AiQuotaExceeded` y `AiTimeout` → siguiente sin evitación; `AiKeyInvalid` se propaga. Los candidatos en evitación pasan al final y solo se usan si no queda otro. Al agotarse, lanzar el error más informativo: `AiQuotaExceeded` > `AiTimeout` > `AiProviderUnavailable` (research R5); un corte por falta de tiempo cuenta como `AiTimeout`. Hace pasar T016 y T017

**Checkpoint**: US1 y US2 funcionan; SC-002 (análisis dentro de los 55 s con el primero saturado) cubierto por T016.

---

## Phase 5: User Story 3 — Preferir modelos con capa gratuita (P2)

**Goal**: lista de preferencia opcional que manda sobre el orden automático (FR-004, FR-006, spec Assumptions).

**Independent Test**: `ai_model="m-a,m-b"` con ambos disponibles usa `m-a`; al retirarlo del listado usa `m-b`.

### Tests (escribir primero, deben fallar)

- [X] T019 [P] [US3] En `backend/tests/unit/test_ai_model_selector.py` (más una prueba de `Settings` en `backend/tests/unit/test_config_ai_model.py`): `ai_model="a, b,,a"` → `ai_model_preference == ["a", "b"]`; vacío → `[]`; la preferencia manda sobre el orden automático aunque sea un `pro` (no pasa por `is_economic`); si la primera no está en el listado se usa la segunda con `selection="preferred"`; si ninguna está → orden automático con `selection="fallback"`; una entrada ausente del listado produce un único `ai_model_preference_ignored` (warning, campos `user_id` y `model`) por listado, no por análisis; con preferencia vacía y listado vacío de `flash` → `AiNoModelAvailable`
- [X] T020 [P] [US3] En `backend/tests/integration/test_photo_analysis.py` un caso con `ai_model="gemini-3.6-flash"` ya configurado en el entorno (valor único antiguo) que sigue funcionando como primer elemento de la lista (spec Assumptions)

### Implementation

- [X] T021 [US3] En `ai/model_selector.py` aplicar la preferencia (research R3): entradas presentes en el catálogo y con `generate_content` se anteponen en su orden; las ausentes se ignoran con `get_logger().warning("ai_model_preference_ignored", user_id=str(user_id), model=name)` una vez por catálogo obtenido (no por análisis); sin ninguna válida, orden automático y `selection="fallback"`
- [X] T022 [P] [US3] Actualizar `backend/.env.example` (`AI_MODEL` como preferencia opcional, lista separada por comas, ejemplo `AI_MODEL=gemini-3.6-flash-lite,gemini-3.6-flash`, vacía por defecto, y que el modelo se descubre solo) y `docs/deploy/produccion.md` (fila `AI_MODEL` / `AI_TIMEOUT_S`: «preferencia opcional de modelos, separada por comas, vacía por defecto; 55 s»)

---

## Phase 6: User Story 4 — Guardar la clave nunca depende de un modelo (P2)

**Goal**: dejar fijado como requisito lo que ya está hecho (FR-010, SC-003).

**Independent Test**: con todos los modelos en 503, `PUT /v1/ai-key` con clave válida responde 200.

- [X] T023 [P] [US4] En `backend/tests/integration/test_ai_key.py`: con `ai.models = ["gemini-3.6-flash"]` y `ai.model_outcomes = {"gemini-3.6-flash": "overloaded"}` y `analyze_outcome="unavailable"`, `PUT /v1/ai-key` con `validate_outcome="ok"` → 200 y `ai.models_tried == []` (guardar no genera nada); con `validate_outcome="invalid"` → `422 AI_KEY_INVALID`. En `backend/tests/test_ai_gemini_validate.py` ya existen las pruebas de `validate_key` sin llamar a `generateContent`: confirmar que siguen pasando con el constructor nuevo (T007)

---

## Phase 7: User Story 5 — Diagnosticar fallos sin adivinar (P3)

**Goal**: cada fallo deja categoría, código y modelo, y ningún dato sensible (FR-011, FR-012, SC-005, SC-006).

**Independent Test**: provocar un fallo de cada tipo y leer la categoría en el registro.

### Tests (escribir primero, deben fallar)

- [X] T024 [P] [US5] En `backend/tests/privacy/test_logs_no_secrets.py` ampliar `test_evento_ai_analysis_no_lleva_foto_respuesta_clave_ni_descripcion`: añadir `model`, `selection` y `attempts` al conjunto de campos permitidos de `ai_analysis`; nuevo caso con dos modelos (1.º `overloaded`, 2.º OK) que comprueba que hay un `ai_model_attempt` con `{"event","level","timestamp","user_id","model","category","status"}` como máximo, `user_id` igual al del usuario de la prueba, `category == "overloaded"`; otro caso con `ai.list_outcome="unavailable"` que comprueba un `ai_model_list_failed` con `user_id` y `category`; y que ni la clave, ni su `sha256`, ni la descripción, ni la foto, ni el texto devuelto aparecen en la salida
- [X] T025 [P] [US5] En `backend/tests/unit/test_ai_model_selector.py`: una prueba que recorre las categorías `model_not_found` (404), `overloaded` (503), `quota` (429), `timeout`, `network` (otro `AiProviderUnavailable`) y comprueba que cada fallo emite `ai_model_attempt` con esa `category` y el `model` correcto (captura de `structlog`)

### Implementation

- [X] T026 [US5] En `ai/model_selector.py::run` emitir `get_logger().warning("ai_model_attempt", user_id=str(user_id), model=..., category=...)` en cada intento fallido, con `status` cuando el proveedor lo conozca (404, 429, 503); y `get_logger().warning("ai_model_list_failed", user_id=str(user_id), category=...)` cuando falle la obtención del listado (incluso si se usa el catálogo viejo o la preferencia); las categorías exactas son las de `contracts/provider-and-errors.md` §5. No registrar mensajes, cuerpos, la clave ni su hash. El evento `ai_analysis` de T013 ya lleva `model`, `selection` y `attempts`
- [X] T027 [US5] En `ai/service.py` el resultado `ai_analysis` en fallo usa el mismo `model` y `attempts` que el éxito (el último intentado, o ausente si no se llegó a ninguno, p. ej. `no_model`). Comprobarlo con el caso (c) de T011

---

## Phase 8: Polish y verificación

- [X] T028 [P] Prueba de la app que garantiza el comportamiento ante el código nuevo (research R10): en `app/test/photo/pending_analysis_notifier_test.dart` añadir el caso `ApiError('AI_NO_MODEL_AVAILABLE', 503)` y comprobar que el borrador se conserva y la persona puede continuar a mano. Si el notificador no lo trata como fallo genérico, mapearlo en `app/lib/features/photo/pending_analysis_notifier.dart` junto a `AI_PROVIDER_UNAVAILABLE` (misma causa `provider_unavailable`) sin cambiar la interfaz
- [X] T029 [P] Documentar el código nuevo: añadir `AI_NO_MODEL_AVAILABLE` (503, «sin modelo compatible para la clave») al enum de `ErrorBody.code` y a la tabla de errores de `specs/001-acceso-y-despliegue/contracts/openapi.yaml`
- [X] T030 Ejecutar `cd backend && uv run ruff check && uv run ruff format --check && uv run pytest` y `cd app && flutter analyze && flutter test` en verde
- [ ] T031 Seguir `quickstart.md` §1 (pruebas por historia) y §3 (privacidad); el §2 (móvil) tras desplegar desde `main`

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2 → Phase 3**. T008 y T013–T015 dependen de T012 (el selector existe).
- **Phase 2**: T002 antes de T006, T007 y T012; T003, T004 y T005 son independientes entre sí.
- **US1** (MVP) no depende de US2–US5.
- **US2** amplía `model_selector.py` (T018) sobre T012; hace pasar T016 y T017.
- **US3** amplía `model_selector.py` (T021) sobre T012; T022 es independiente.
- **US4** solo añade pruebas; puede hacerse tras Phase 2.
- **US5** amplía `model_selector.py` (T026) y `service.py` (T027); sus pruebas pueden escribirse antes.
- Los cambios en `ai/model_selector.py` de T012, T018, T021 y T026 se hacen en orden (mismo fichero).

### Parallel opportunities

- Phase 2: T003, T004 y T005 a la vez.
- US1: T009, T010 y T011 a la vez (ficheros de test distintos o secciones independientes).
- US2: T016 y T017 a la vez.
- US3: T019, T020 y T022 a la vez.
- Después de Phase 2, US4 (T023) puede ir en paralelo con US1.

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: la foto ya no depende de un modelo fijo ni muere cuando uno se retira. Es lo que originó la feature.
2. **Incremento 2 = US2**: tolera saturación y límites. Es el segundo fallo observado, por eso también es P1; no conviene desplegar solo US1 en producción si los modelos nuevos se saturan.
3. **Incremento 3 = US3**: preferencia para la capa gratuita.
4. **Incremento 4 = US4 + US5**: pruebas de la clave y registro completo.
5. Cierre: Phase 8 y despliegue desde `main` con prueba en el móvil (principio IX).
