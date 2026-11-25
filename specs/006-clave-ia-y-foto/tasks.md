# Tasks: Clave de IA y registro por foto

**Input**: Design documents from `specs/006-clave-ia-y-foto/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R16, R13a), data-model.md, contracts/ (`api-changes.md`, `ui-flows.md`), quickstart.md

**Tests**: se incluyen, siguiendo la práctica de la 001–005 y el principio VI. Los tests de cada historia se escriben antes y deben fallar.

**Organization**: por historia de usuario. US1 (clave) es la base de todo lo demás. US2 (foto, camino feliz) depende de US1. US3 (borradores, camino de fallo) amplía los mismos ficheros de US2. US4 (foto desactivada) es sobre todo de interfaz y depende del estado de US1.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de `spec.md` (US1 clave de IA, US2 registrar con foto, US3 borradores, US4 foto desactivada sin clave)
- Rutas de backend relativas a `backend/src/mykcal/` salvo que se indique `backend/tests/` o `backend/alembic/`; las de la app, a `app/`.

---

## Phase 1: Setup

- [x] T001 Comprobar que la rama es `006-clave-ia-y-foto` y que `cd backend && uv run ruff check && uv run pytest` y `cd app && flutter analyze && flutter test` pasan antes de empezar (línea base de la 005)

---

## Phase 2: Foundational (bloquea todas las historias)

### Base de datos y aislamiento del proveedor (R1, R4, R16)

- [x] T002 [P] Añadir a `backend/tests/integration/test_migrate.py` los casos de `0006_ai_key` (suben y bajan): `ai_key` con PK `user_id`; `provider` rechaza un valor fuera de `('gemini')` (CHECK); `user_id` inexistente → error (FK); `downgrade -1` elimina `ai_key`
- [x] T003 Crear `backend/alembic/versions/0006_ai_key.py` (`revision = "0006_ai_key"`, `down_revision = "0005_quick"`, con `downgrade`), constraints verbatim de `data-model.md`: tabla `ai_key` con `user_id uuid NOT NULL PK FK user_account.id`, `provider text NOT NULL CHECK provider IN ('gemini')`, `encrypted_key bytea NOT NULL`, `configured_at timestamptz NOT NULL`. Hace pasar T002
- [x] T004 [P] Crear `backend/src/mykcal/ai/__init__.py` y `backend/src/mykcal/ai/models.py` con `AiKey` (SQLAlchemy 2, mismo estilo que `quick/models.py`) según T003, y registrarlo donde `backend/alembic/env.py` y `backend/tests/conftest.py` cargan el metadata. En `backend/tests/conftest.py` añadir `ai_key` a la lista `TRUNCATE` de la fixture `app`
- [x] T005 En `backend/src/mykcal/config.py` añadir `ai_key_master: str = Field(min_length=1)` (debe decodificar a 32 bytes en base64 o falla al arrancar, `@field_validator`) y `ai_model: str = "gemini-2.0-flash"`, `ai_timeout_s: float = Field(default=55.0, ge=5, le=58)`. En `backend/tests/conftest.py`, fixture `settings`: añadir `ai_key_master=base64.b64encode(secrets.token_bytes(32)).decode()`
- [x] T006 En `backend/src/mykcal/core/errors.py` añadir a `ErrorCode`: `AI_KEY_NOT_FOUND` (404), `AI_KEY_INVALID` (422), `AI_KEY_REQUIRED` (403), `AI_PROVIDER_UNAVAILABLE` (503), `AI_QUOTA_EXCEEDED` (429), `AI_RESPONSE_INVALID` (422), `AI_UNRECOGNIZED` (422), `AI_TIMEOUT` (504) (`contracts/api-changes.md`)
- [x] T007 En `backend/src/mykcal/logging.py` añadir `"model"` a `ALLOWED_FIELDS` (`"result"`, `"user_id"` y `"duration_ms"` ya están; research R10: nunca se añade un campo de texto libre con el motivo del fallo)
- [x] T008 [P] Crear `backend/src/mykcal/ai/provider.py`: ABC `AiProvider` con `async def validate_key(self, raw_key: str) -> None` (no retorna nada; lanza una de las excepciones de abajo si falla) y `async def analyze_photo(self, raw_key: str, image: bytes, prompt: str) -> str` (devuelve el texto crudo de la respuesta); excepciones de dominio `AiKeyInvalid`, `AiQuotaExceeded`, `AiProviderUnavailable`, `AiTimeout` (todas `Exception`), según research R4
- [x] T009 [P] Crear `backend/src/mykcal/ai/fake.py`: `FakeProvider(AiProvider)` con atributos configurables por test (`validate_outcome: Literal["ok","invalid","unavailable"]`, `analyze_outcome: Literal["success","key_invalid","quota_exceeded","invalid_json","empty_items","timeout","unavailable"]`, `response_json: str | None` para éxito) que lanza o devuelve según esos atributos; nunca hace red (principio VI, FR-019)
- [x] T010 [P] Crear `backend/src/mykcal/ai/crypto.py`: `encrypt_key(raw_key: str, master_b64: str) -> bytes` (AES-256-GCM, nonce de 12 bytes aleatorio, `nonce ‖ ciphertext ‖ tag`) y `decrypt_key(blob: bytes, master_b64: str) -> str`, con `cryptography.hazmat.primitives.ciphers.aead.AESGCM` (research R1). Crear `backend/tests/unit/test_ai_crypto.py`: cifrar y descifrar vuelve al texto original; descifrar con una clave maestra distinta lanza una excepción; dos cifrados de la misma clave producen bytes distintos (nonce aleatorio); el blob cifrado no contiene la clave en texto claro
- [x] T011 En `backend/pyproject.toml` añadir `cryptography>=42` a `dependencies` (ya está en el lockfile de forma transitiva; se declara explícita porque el código de producción la importa directamente)
- [x] T012 Crear `backend/src/mykcal/ai/router.py` con `APIRouter()` cuyas rutas dependen de `require_consent`. En `backend/src/mykcal/main.py`: importar e incluir `ai_router` (sin restricción de orden: `/v1/ai-key` y `/v1/photo-analysis` no colisionan con ninguna ruta existente), añadir el parámetro `ai_provider: AiProvider | None = None` a `create_app` y guardar `app.state.ai_provider = ai_provider or GeminiProvider(settings.ai_model, settings.ai_timeout_s)` (mismo patrón que `off_transport`). Las rutas concretas las añaden las historias
- [x] T013 Actualizar `specs/001-acceso-y-despliegue/contracts/openapi.yaml` con el fragmento de `specs/006-clave-ia-y-foto/contracts/api-changes.md`: 4 rutas (`GET/PUT/DELETE /v1/ai-key`, `POST /v1/photo-analysis`), schemas `AiKeyStatus`, `AiKeyCreate`, `PhotoAnalysisResult`, `ProposedItem`, los 8 códigos nuevos en el enum de `ErrorBody.code`, `info.version: 0.6.0`

### Base de la app

- [x] T014 [P] En `app/pubspec.yaml` añadir `image_picker: ^1.1.2` (cámara y galería, research R14) y `shared_preferences: ^2.3.0` (borradores, research R12) a `dependencies`; ejecutar `flutter pub get`
- [x] T015 [P] Crear `app/lib/features/photo/draft_model.dart` (`PhotoDraft` con `id`, `meal`, `entryDate`, `description`, `totalGrams`, `failureCode`, `failureReason`, `photoPath`, `proposalJson`, `createdAt`, según `data-model.md`, con `toJson`/`fromJson`) y `app/lib/features/photo/drafts_store.dart` (`list()`, `save(PhotoDraft)`, `remove(String id)` sobre `shared_preferences`, serializando la lista como JSON bajo la clave `photo_drafts`; al superar 20 elementos descarta el más antiguo por `createdAt`). Crear `app/test/photo/drafts_store_test.dart`: guardar y listar, eliminar, descartar el más antiguo al superar 20, persiste entre instancias (mismo `SharedPreferences.setMockInitialValues`)

**Checkpoint**: T002 en verde; `alembic upgrade head` y `downgrade -1` funcionan; el contrato 0.6.0 es válido; `ruff check` y `flutter analyze` sin avisos; T010 y T015 en verde.

---

## Phase 3: User Story 1 - Configurar la clave de IA (Priority: P1) 🎯 MVP

**Goal**: el usuario obtiene su clave de Gemini con una guía, la pega, la app la comprueba y la guarda cifrada; puede sustituirla o quitarla; nunca se muestra ni se registra.

**Independent Test**: pegar una clave válida (queda configurada con fecha), una inválida (se rechaza con mensaje) y quitarla (la foto vuelve a aparecer desactivada) — escenarios 1–5 de `quickstart.md`.

### Tests for User Story 1 ⚠️ (escribir primero; deben fallar)

- [x] T016 [P] [US1] `backend/tests/integration/test_ai_key.py`: `PUT` con `FakeProvider(validate_outcome="ok")` → `200 AiKeyStatus` (`has_key=true`, `provider="gemini"`, `configured_at`); `GET` tras guardar → `200` igual; `PUT` otra vez (sustituir) → `configured_at` nueva; `DELETE` → `204`; `GET` tras `DELETE` → `404 AI_KEY_NOT_FOUND`; `DELETE` sin clave previa → `204` (idempotente); `PUT` con `FakeProvider(validate_outcome="invalid")` → `422 AI_KEY_INVALID` y no se guarda nada (`GET` sigue en 404); `PUT` con `FakeProvider(validate_outcome="unavailable")` → `503 AI_PROVIDER_UNAVAILABLE`
- [x] T017 [P] [US1] Crear `backend/tests/privacy/test_no_key_in_response.py`: tras `PUT /v1/ai-key` con una clave de prueba conocida, recorrer recursivamente el JSON de las respuestas de `GET`, `PUT` y `DELETE /v1/ai-key` y comprobar que ningún valor de cadena contiene esa clave ni una subcadena de 8+ caracteres de ella (FR-004, SC-003)
- [x] T018 [P] [US1] Crear `backend/tests/privacy/test_user_isolation_ai.py` con los casos de la clave: el usuario A guarda su clave; el usuario B hace `GET /v1/ai-key` → `404` (no ve la de A); B guarda la suya; A sigue viendo la suya sin cambios; B hace `DELETE` → solo afecta a la suya, la de A sigue activa
- [x] T019 [P] [US1] En `backend/tests/privacy/test_consent_gate.py` añadir `GET/PUT/DELETE /v1/ai-key` a `HEALTH_DATA_ROUTES`; comprobar que `test_all_routes_require_identity.py` las cubre. Nota: `POST /v1/photo-analysis` se añade en US2 (T049a), no aquí, porque la ruta todavía no existe en esta fase
- [x] T020 [P] [US1] Crear `backend/tests/contract/test_ai_contract.py`: respuestas de `GET/PUT/DELETE /v1/ai-key` válidas contra `openapi.yaml` 0.6.0 (200, 404, 422, 503)
- [x] T021 [P] [US1] Crear `app/test/ai_key/ai_key_guide_test.dart`: sin clave muestra los pasos y el campo oscurecido; guardar una clave válida muestra «Clave configurada» con la fecha; una inválida muestra el mensaje bajo el campo sin navegar; con clave, «Cambiar clave» vuelve a mostrar el campo y «Quitar clave» pide confirmación y, al aceptar, vuelve al estado sin clave; en modo onboarding se ve «Omitir»; fuera de onboarding, no

### Implementation for User Story 1

- [x] T022 [P] [US1] Crear `backend/src/mykcal/ai/schemas.py` con `AiKeyStatus` (`has_key: Literal[True]`, `provider: Literal["gemini"]`, `configured_at: datetime`) y `AiKeyCreate` (`raw_key: str = Field(min_length=1, max_length=256)`, `extra="forbid"`), según `contracts/api-changes.md`
- [x] T023 [US1] Crear `backend/src/mykcal/ai/repository.py` con `get_key(session, user_id) -> AiKey | None`, `upsert_key(session, user_id, provider, encrypted_key, now)` (`INSERT … ON CONFLICT (user_id) DO UPDATE`) y `delete_key(session, user_id) -> bool`. Siempre filtran por `user_id` (principio V). Depende de T004
- [x] T024 [US1] Crear `backend/src/mykcal/ai/gemini.py` con `GeminiProvider(AiProvider)`: `validate_key(raw_key)` hace `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={raw_key}` con un prompt trivial y `maxOutputTokens: 1` (`httpx.AsyncClient`, timeout corto); 401/403 → `AiKeyInvalid`; timeout o 5xx → `AiProviderUnavailable`; 200 → retorna. `analyze_photo` levanta `NotImplementedError` por ahora (se completa en US2). Depende de T008
- [x] T025 [US1] Crear `backend/src/mykcal/ai/service.py` con:
  - `save_key(session, user_id, provider, raw_key, ai_provider, master_b64, now) -> AiKeyStatus`: llama `ai_provider.validate_key(raw_key)`; `AiKeyInvalid` → `422 AI_KEY_INVALID`; `AiProviderUnavailable` → `503 AI_PROVIDER_UNAVAILABLE`; si vale, cifra con `crypto.encrypt_key` (T010) y hace `upsert_key` (T023)
  - `get_key_status(session, user_id) -> AiKeyStatus`: `404 AI_KEY_NOT_FOUND` si no hay clave
  - `delete_key(session, user_id) -> None`
  - Depende de T010, T022, T023, T024
- [x] T026 [US1] En `backend/src/mykcal/ai/router.py` añadir `GET /v1/ai-key` → `AiKeyStatus`, `PUT /v1/ai-key` (body `AiKeyCreate`) → `AiKeyStatus`, `DELETE /v1/ai-key` → `204`, todas con `require_consent` e inyectando `request.app.state.ai_provider` y `request.app.state.settings.ai_key_master`. Hace pasar T016, T017, T020
- [x] T027 [US1] Privacidad: ampliar `backend/tests/privacy/test_consent_gate.py` y `test_all_routes_require_identity.py` (T019) con las 3 rutas reales de la clave; hacer pasar T018
- [x] T028 [P] [US1] En `app/lib/core/api/models.dart` añadir `AiKeyStatus` (`hasKey`, `provider`, `configuredAt`) con `fromJson`
- [x] T029 [US1] En `app/lib/core/api/mykcal_api.dart` añadir `getAiKey()` (null si `404`), `saveAiKey(String rawKey)`, `deleteAiKey()`, mapeando `AI_KEY_INVALID` y `AI_PROVIDER_UNAVAILABLE` a excepciones tipadas (como el resto de `ApiException`). Depende de T028
- [x] T030 [US1] Crear `app/lib/features/ai_key/ai_key_controller.dart`: `AsyncNotifier<AiKeyStatus?>` con `load()`, `save(String rawKey)` y `delete()`, invalidando el estado tras cada cambio
- [x] T031 [US1] Crear `app/lib/features/ai_key/ai_key_guide_screen.dart` según `contracts/ui-flows.md` Pantalla 1: pasos numerados, campo oscurecido, «Guardar clave», estado con clave («Cambiar»/«Quitar» con confirmación), «Omitir» solo si `onboarding: true`. Hace pasar T021
- [x] T032 [US1] En `app/lib/features/settings/settings_screen.dart` añadir la fila «Clave de IA» (configurada con fecha o «No configurada») que abre `AiKeyGuideScreen`
- [x] T033 [US1] En `app/lib/app.dart` (`AppGate`), cuando `Onboarding.done`: leer la bandera local `onboarding_ai_key_seen` (`shared_preferences`); si es falsa, mostrar `AiKeyGuideScreen(onboarding: true)` en vez de `HomeScreen`; al guardar u omitir, marcar la bandera a verdadera y navegar a `HomeScreen` (research R13a)
- [x] T034 [US1] Textos nuevos en `app/lib/l10n/app_es.arb` (guía, estados, mensajes de error) y regenerar `app_localizations`
- [x] T035 [US1] Accesibilidad en `app/test/ai_key/ai_key_a11y_test.dart`: campo con `labelText` y `obscureText`, cada paso con `Semantics`, botones con etiqueta completa, contraste en claro y oscuro, texto al 200 % sin cortes (FR-020)

**Checkpoint**: US1 funciona sola: guardar, sustituir, quitar la clave; nunca se expone. Escenarios 1–5.

---

## Phase 4: User Story 2 - Registrar un plato con una foto (Priority: P1)

**Goal**: con clave configurada, el usuario hace una foto, la IA propone alimentos emparejados con la base, el usuario corrige y guarda; la foto nunca se guarda en el servidor; el envío no bloquea la app.

**Independent Test**: con una respuesta de la IA guardada (`FakeProvider`), fotografiar un plato, corregir un gramaje, sustituir un alimento y guardar; comprobar que las entradas usan valores de la base y que la foto no queda en el servidor — escenarios 6–13 de `quickstart.md`.

### Tests for User Story 2 ⚠️ (escribir primero; deben fallar)

- [x] T036 [P] [US2] Crear `backend/tests/unit/test_ai_prompt.py`: `build_prompt(description, total_grams)` incluye la descripción y los gramos cuando se dan, y los omite cuando son `None`; `parse_response(raw_json)` con un JSON válido devuelve la lista de `(name, grams)`; JSON con alimentos duplicados los agrupa sumando los gramos; gramos de `0` o `> 2000` quedan marcados (`flagged=True`)
- [x] T037 [P] [US2] Crear `backend/tests/unit/test_ai_matching.py`: un nombre parecido (≥ 0.5 de `word_similarity`) a un alimento visible de la base se empareja con sus valores; un nombre sin parecido da `matched_food=None` y `kcal=None`; usa `foods.repository.search` y filtra por lo visible para el usuario (personalizados ajenos no emparejan)
- [x] T038 [P] [US2] Crear `backend/tests/integration/test_photo_analysis.py` (camino feliz): con `FakeProvider(analyze_outcome="success", response_json=…)` y una clave guardada, `POST /v1/photo-analysis` (multipart: `photo`, `meal`, `entry_date`) → `200 PhotoAnalysisResult` con los alimentos emparejados y sus kcal; sin clave configurada → `403 AI_KEY_REQUIRED`; foto de más de 4 MB → `413`
- [x] T039 [P] [US2] Crear `backend/tests/privacy/test_photo_not_stored.py`: tras un análisis con éxito y uno fallido, ningún fichero temporal del proceso ni ninguna fila de ninguna tabla contiene los bytes de la foto enviada (SC-003, FR-012)
- [x] T040 [P] [US2] En `backend/tests/contract/test_ai_contract.py` (T020) añadir `POST /v1/photo-analysis` (200) contra `openapi.yaml` 0.6.0
- [x] T041 [P] [US2] Crear `app/test/photo/photo_capture_test.dart`: elegir foto (mock de `image_picker`), descripción y gramos opcionales, «Analizar» navega de vuelta al diario sin esperar respuesta (no bloqueante, research R8); permiso de cámara denegado ofrece «Elegir de la galería»
- [x] T042 [P] [US2] Crear `app/test/photo/pending_analysis_notifier_test.dart`: al enviar, el estado pasa a «pendiente»; con éxito (mock de `analyzePhoto`) pasa a «listo» y guarda un borrador con `proposalJson` (sin `failureCode`) en `drafts_store`; mientras está pendiente, otras operaciones del diario (añadir por búsqueda) no se bloquean
- [x] T043 [P] [US2] Crear `app/test/photo/proposal_edit_test.dart`: cambiar los gramos de un alimento recalcula los totales; «Cambiar» sustituye el alimento emparejado; «✕» quita uno; un alimento sin pareja desactiva «Guardar en {comida}»; «Crear» abre `CustomFoodFormScreen` con el nombre de la IA precargado y, al guardar, lo empareja; al confirmar, llama a `addEntry` por cada alimento resuelto y navega al diario con el día actualizado

### Implementation for User Story 2

- [x] T044 [US2] Ampliar `backend/src/mykcal/ai/schemas.py` (T022) con `ProposedItem` (`ai_name: str`, `ai_grams: Decimal`, `flagged: bool`, `matched_food: FoodSummary | None`, `matched_similarity: float | None`, `kcal: Decimal | None`, `protein_g`, `carbs_g`, `fat_g`) y `PhotoAnalysisResult` (`items: list[ProposedItem]`), según `contracts/api-changes.md`
- [x] T045 [US2] Crear `backend/src/mykcal/ai/prompt.py` (puro; research R6): `build_prompt(description: str | None, total_grams: int | None) -> str`; `parse_response(raw_json: str) -> list[RawItem]` que valida con un schema Pydantic interno (`items: list[{name: str, grams: float}]`), agrupa duplicados por nombre normalizado sumando gramos y marca `flagged=True` si `grams == 0` o `grams > 2000`; lanza `AiResponseInvalid` si el JSON no es válido o no cumple el schema, `AiUnrecognized` si `items` queda vacío tras agrupar. Hace pasar T036
- [x] T046 [US2] Crear `backend/src/mykcal/ai/matching.py` (research R7): `match_items(session, user_id, raw_items: list[RawItem]) -> list[ProposedItem]`: por cada `RawItem`, normaliza el nombre (`foods.text.normalize`), busca con `foods.repository.search(session, user_id, q_norm)`, si el primer candidato tiene similitud ≥ `0.5` lo empareja (kcal y macros = valores por 100 del alimento × `ai_grams / 100`); si no, `matched_food=None`. Hace pasar T037. Depende de T044, T045
- [x] T047 [US2] Ampliar `backend/src/mykcal/ai/gemini.py` (T024): implementar `analyze_photo(raw_key, image, prompt)` con `httpx`, `POST …:generateContent?key={raw_key}` con `inlineData` en base64 (`image/jpeg`) y `response_mime_type: "application/json"`, timeout de `settings.ai_timeout_s`; devuelve el texto de la respuesta tal cual (la validación la hace `prompt.parse_response`)
- [x] T048 [US2] Crear `backend/src/mykcal/ai/service.py::analyze_photo(session, user_id, ai_provider, master_b64, photo, meal, entry_date, description, total_grams, now) -> PhotoAnalysisResult`: si no hay clave (T023) → `403 AI_KEY_REQUIRED`; descifra con `crypto.decrypt_key` (T010); llama `ai_provider.analyze_photo` con el prompt de `build_prompt` (T045); valida con `parse_response` (T045) y empareja con `match_items` (T046); registra `ai_analysis` con `user_id`, `result="success"`, `model`, `duration_ms` (R10). Depende de T044, T045, T046, T047
- [x] T049 [US2] En `backend/src/mykcal/ai/router.py` añadir `POST /v1/photo-analysis` (`photo: UploadFile`, `meal: Meal = Form()`, `entry_date: date = Form()`, `description: str | None = Form(max_length=500)`, `total_grams: int | None = Form(ge=1)`; rechaza con `413` si `photo.size` o los bytes leídos superan 4 MB) usando `service.analyze_photo` (T048). Hace pasar T038, T040
- [x] T049a [P] [US2] En `backend/tests/privacy/test_consent_gate.py` añadir `POST /v1/photo-analysis` a `HEALTH_DATA_ROUTES` (las 4 rutas de la 006 exigen `require_consent`, `contracts/api-changes.md`); comprobar que `test_all_routes_require_identity.py` la cubre también. Depende de T049
- [x] T050 [US2] Verificar `test_photo_not_stored` (T039) contra el router real: ningún `UploadFile` se escribe a disco; los bytes se leen con `await photo.read()` y se descartan al salir de la función
- [x] T051 [P] [US2] En `app/lib/core/api/models.dart` (T028) añadir `PhotoAnalysisResult` y `ProposedItem` con `fromJson`/`toJson` (se necesita `toJson` para serializar `proposalJson` en los borradores)
- [x] T052 [US2] En `app/lib/core/api/mykcal_api.dart` añadir `analyzePhoto({required File photo, required Meal meal, required DateTime entryDate, String? description, int? totalGrams})` (multipart), mapeando `AI_KEY_REQUIRED`, `413`, `AI_RESPONSE_INVALID`, `AI_UNRECOGNIZED` a excepciones tipadas (los códigos de fallo de US3 se añaden en esa historia). Depende de T051
- [x] T053 [P] [US2] Crear `app/lib/features/photo/photo_capture_screen.dart` según `contracts/ui-flows.md` Pantalla 4 (paso 1): `image_picker` para cámara/galería, permiso denegado ofrece galería, campos de descripción y gramos opcionales, redimensiona a 1024 px y comprime a JPEG ~80 % antes de «Analizar». Al pulsar «Analizar», llama a `pending_analysis_notifier` (T054) y navega de vuelta de inmediato. Hace pasar T041
- [x] T054 [US2] Crear `app/lib/features/photo/pending_analysis_notifier.dart`: `Notifier` (`family` por `meal` + `date`) que, en segundo plano, llama `analyzePhoto` (T052); con éxito guarda un borrador con `proposalJson` en `drafts_store` (T015) y expone el estado «listo»; mientras está en vuelo expone «pendiente» sin bloquear ninguna otra pantalla. Hace pasar T042. Depende de T015, T052
- [x] T055 [US2] Crear `app/lib/features/photo/analysis_chip.dart`: chip «Analizando…» / «Análisis listo ✓» leído de `pending_analysis_notifier` (T054); al tocar «listo» abre `ProposalEditScreen` (T058) con el `proposalJson` guardado
- [x] T056 [US2] En `app/lib/features/diary/meal_section.dart` añadir `aiKeyConfigured: bool` y `onPhoto: VoidCallback?`: icono de cámara junto al «+» (activo si `onPhoto != null`) y, cuando hay un análisis en curso o listo para esa comida, `AnalysisChip` (T055) bajo la cabecera
- [x] T057 [US2] En `app/lib/features/diary/diary_screen.dart` añadir `_photo(context, date, meal)`: si `aiKeyConfigured` (de `ai_key_controller`, T030) abre `PhotoCaptureScreen` (T053); pásalo a `MealSection.onPhoto`
- [x] T058 [US2] Crear `app/lib/features/photo/proposal_edit_screen.dart` y `app/lib/features/photo/proposed_item_tile.dart` según `contracts/ui-flows.md` Pantalla 5: fila con nombre de la IA, alimento emparejado (o aviso «Sin equivalente en tu base» con «Buscar»/«Crear»/«✕»), gramos y kcal; tocar abre la hoja de cantidad de la 004 con `ai_grams` como sugerida; «Cambiar» abre `FoodSearchScreen(onSelected: …)`; «Crear» abre `CustomFoodFormScreen(initialName: item.aiName, onSaved: …)`; totales al pie; «Guardar en {comida}» desactivado si queda algún `matchedFood == null`, y al confirmar llama `addEntry` por cada alimento y elimina el borrador pendiente (T015) de esta foto. Hace pasar T043
- [x] T059 [US2] Textos nuevos en `app/lib/l10n/app_es.arb` (captura, chip, propuesta) y regenerar `app_localizations`
- [x] T060 [US2] Accesibilidad de captura y propuesta en `app/test/photo/photo_a11y_test.dart`: etiquetas de los campos, fila de alimento legible entera, botones con nombre completo, contraste en claro y oscuro, texto al 200 % sin cortes (FR-020)

**Checkpoint**: US2 funciona con el camino feliz: foto → propuesta → corrección → guardado, sin bloquear la app y sin guardar la foto. Escenarios 6–13. US1 sigue verde.

---

## Phase 5: User Story 3 - Borradores cuando la IA falla (Priority: P1)

**Goal**: cuando el análisis falla por cualquier causa (clave, cuota, respuesta inválida, plato no reconocido, tiempo agotado, proveedor caído, app cerrada), la foto queda como borrador con un mensaje claro; el usuario puede reintentar, continuar a mano o descartar.

**Independent Test**: simular clave revocada, cuota agotada, respuesta inválida y plato no reconocido con `FakeProvider`; comprobar en cada caso el borrador, el mensaje y la continuación manual — escenarios 14–19 y 22–24, 27 de `quickstart.md`.

### Tests for User Story 3 ⚠️ (escribir primero; deben fallar)

- [x] T061 [P] [US3] Ampliar `backend/tests/integration/test_photo_analysis.py` (T038) con `FakeProvider`:
  - `analyze_outcome="key_invalid"` → `422 AI_KEY_INVALID`
  - `analyze_outcome="quota_exceeded"` → `429 AI_QUOTA_EXCEEDED`
  - `analyze_outcome="invalid_json"` → `422 AI_RESPONSE_INVALID`
  - `analyze_outcome="empty_items"` → `422 AI_UNRECOGNIZED`
  - `analyze_outcome="timeout"` → `504 AI_TIMEOUT`
  - `analyze_outcome="unavailable"` → `503 AI_PROVIDER_UNAVAILABLE`
  - cada caso registra un evento `ai_analysis` con el `result` correspondiente (R10, FR-017)
- [x] T062 [P] [US3] Ampliar `backend/tests/privacy/test_logs_no_secrets.py`: el evento `ai_analysis` (éxito y los 6 fallos) nunca contiene la foto, la respuesta de la IA, la clave ni la descripción (SC-003, SC-005)
- [x] T063 [P] [US3] Crear `app/test/photo/drafts_controller_test.dart`: `list()` refleja `drafts_store`; `discard(id)` elimina el borrador y su foto local; `completeManually(id)` lo elimina sin tocar las entradas; guardar un borrador número 21 descarta el más antiguo (T015)
- [x] T064 [P] [US3] Crear `app/test/photo/drafts_screen_test.dart`: cada borrador muestra la comida, el día y la causa, con «Reintentar», «Añadir a mano» y «Descartar» (con confirmación); vacío con «No tienes borradores.»; al completar o descartar, desaparece de la lista
- [x] T065 [P] [US3] Ampliar `app/test/photo/pending_analysis_notifier_test.dart` (T042): cada `ErrorCode` de fallo (T061) crea un borrador con el `failureCode`/`failureReason` de `contracts/ui-flows.md` (R11) y la acción correspondiente (ir a ajustes, reintentar, ver borrador); si el `Notifier` se descarta (simulando el cierre de la app) antes de que la petición termine, al reconstruirse dentro de la ventana de 60 s dicha foto queda como borrador con `failureCode: "interrupted"`

### Implementation for User Story 3

- [x] T066 [US3] Ampliar `backend/src/mykcal/ai/gemini.py::analyze_photo` (T047): mapea 401/403 → `AiKeyInvalid`, 429 → `AiQuotaExceeded`, timeout de `httpx` → `AiTimeout`, 5xx o error de red → `AiProviderUnavailable`
- [x] T067 [US3] Ampliar `backend/src/mykcal/ai/service.py::analyze_photo` (T048): envuelve la llamada al proveedor y a `parse_response` en un `try`/`except` que traduce cada excepción de dominio (`AiKeyInvalid`, `AiQuotaExceeded`, `AiProviderUnavailable`, `AiTimeout` de T008/T066; `AiResponseInvalid`, `AiUnrecognized` de T045) al `ApiError` correspondiente de la tabla de `research.md` R11, y registra `ai_analysis` con el `result` de esa rama en cada caso (nunca la causa en texto libre, R10). Hace pasar T061, T062
- [x] T068 [P] [US3] En `app/lib/core/api/mykcal_api.dart::analyzePhoto` (T052) completar el mapeo de `AI_KEY_INVALID`, `AI_QUOTA_EXCEEDED`, `AI_TIMEOUT`, `AI_PROVIDER_UNAVAILABLE` a excepciones tipadas (los dos primeros ya mapeados en T052)
- [x] T069 [US3] Crear `app/lib/features/photo/drafts_controller.dart`: `AsyncNotifier<List<PhotoDraft>>` sobre `drafts_store` (T015) con `discard(id)`, `completeManually(id)` y `retry(id)` (relanza `pending_analysis_notifier` con los datos del borrador). Hace pasar T063
- [x] T070 [US3] Crear `app/lib/features/photo/drafts_screen.dart` según `contracts/ui-flows.md` Pantalla 6: lista con causa y las tres acciones, confirmación al descartar, vacío. Hace pasar T064
- [x] T071 [US3] Ampliar `app/lib/features/photo/pending_analysis_notifier.dart` (T054): en cada código de fallo, construye el `PhotoDraft` con `failureCode`/`failureReason` de `contracts/ui-flows.md` (R11) y lo guarda en `drafts_store`; añade un `WidgetsBindingObserver` (o equivalente al ciclo de vida del provider) que, si el proceso termina antes de recibir respuesta, deja un borrador `failureCode: "interrupted"` al reabrir la app. Además, captura por separado el error de conectividad (p. ej. `DioException` sin respuesta del servidor, al enviar o mientras espera) antes de que llegue ningún código HTTP, y crea el borrador con `failureCode: "no_connection"` y el mensaje «Sin conexión. Se ha guardado como borrador.» con acción «Reintentar» (research R11, edge case «Sin conexión al enviar la foto», escenario 24 de `quickstart.md`). Hace pasar T065
- [x] T072 [US3] Añadir el acceso a `DraftsScreen` (T070) desde `app/lib/features/diary/diary_screen.dart` (indicador o botón visible solo cuando `drafts_controller` tiene elementos)
- [x] T073 [US3] Textos de los 6 mensajes de fallo y de la pantalla de borradores en `app/lib/l10n/app_es.arb` (research R11) y regenerar `app_localizations`
- [x] T074 [US3] Accesibilidad de la pantalla de borradores en `app/test/photo/photo_a11y_test.dart` (T060): cada fila se lee entera (comida, día, causa), botones con etiqueta completa, contraste y texto al 200 %

**Checkpoint**: US3 funciona junto con US2: ningún fallo pierde la comida; app cerrada durante el análisis es recuperable. Escenarios 14–19, 22–24, 27. US1 y US2 siguen verdes.

---

## Phase 6: User Story 4 - Foto desactivada sin clave (Priority: P2)

**Goal**: sin clave, la opción de foto aparece desactivada con acceso a la guía; el resto de la app (búsqueda, escáner, recientes, favoritos, copiar) funciona exactamente igual.

**Independent Test**: sin clave, comprobar que la foto aparece desactivada con acceso a la guía y que búsqueda, código de barras y registro rápido funcionan — escenarios 20–21 de `quickstart.md`.

### Tests for User Story 4 ⚠️ (escribir primero; deben fallar)

- [x] T075 [P] [US4] Ampliar `app/test/diary/meal_section_test.dart` (o crearlo si no existe): `aiKeyConfigured: false` muestra el icono de cámara en gris con el texto «Necesitas una clave de IA» y, al tocarlo, se notifica para abrir `AiKeyGuideScreen` en vez de `PhotoCaptureScreen`; `aiKeyConfigured: true` muestra el icono activo
- [x] T076 [P] [US4] Ampliar `app/test/diary/diary_screen_test.dart`: sin clave configurada, `_add` (búsqueda, Recientes, Favoritos) y «Copiar de otro día» siguen abriéndose y funcionando exactamente igual que con clave (FR-016)

### Implementation for User Story 4

- [x] T077 [US4] Confirmar en `app/lib/features/diary/meal_section.dart` (T056) el estado desactivado completo de la Pantalla 3 de `contracts/ui-flows.md`: color atenuado, subtítulo explicativo, área táctil de 48 dp igual que activo. Hace pasar T075
- [x] T078 [US4] Confirmar en `app/lib/features/diary/diary_screen.dart::_photo` (T057) que, sin `aiKeyConfigured`, el toque abre `AiKeyGuideScreen` en vez de `PhotoCaptureScreen`. Hace pasar T075
- [x] T079 [US4] Accesibilidad del icono desactivado (tooltip/semántica que explica la causa) en `app/test/photo/photo_a11y_test.dart` (T060, T074)

**Checkpoint**: las 4 historias funcionan juntas. Escenarios 1–27 (salvo 25–26, cámara/avión, y 28–29, a11y general/aislamiento ya cubiertos en US1–US3).

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T080 [P] Revisar `backend/tests/privacy/test_user_isolation_ai.py` (T018): cubre las 4 rutas (incluida `POST /v1/photo-analysis`: B sin clave propia nunca puede analizar aunque A tenga una) con un caso cada una
- [x] T081 [P] Revisar `backend/tests/privacy/test_all_routes_require_identity.py`: las 4 rutas nuevas rechazan una petición sin identidad; `PUBLIC_ROUTES` no cambia
- [x] T082 Revisar que `flutter analyze` y `ruff check` no dejan avisos, que no hay cadenas fuera del ARB, que `cryptography` está declarada en `pyproject.toml` (T011) y que `image_picker`/`shared_preferences` son las únicas dependencias nuevas de la app (research R16)
- [ ] T083 Ejecutar `quickstart.md` §1–§4: pruebas automáticas en verde, `alembic upgrade head` → `downgrade -1` → `upgrade head`, generar y configurar `AI_KEY_MASTER` en `.env` local, y los 30 escenarios de §5 contra el backend local con una clave de Gemini real (incluidos TalkBack, texto al 200 %, el escenario 27 de app cerrada durante el análisis —no el 22, que es registrar durante el análisis sin bloquear— y el escenario 30 de SC-006 con 20 platos habituales)
- [ ] T084 Tras fusionar y desplegar desde `main` (principio IX, `quickstart.md` §6): confirmar `AI_KEY_MASTER` en las variables de Dokploy, repetir en producción los escenarios 2, 6, 12, 14, 20 y 27, y marcar la feature como cerrada

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias
- **Foundational (Phase 2)**: depende de Setup; **bloquea** todas las historias
- **US1 (Phase 3)**: depende solo de Foundational
- **US2 (Phase 4)**: depende de Foundational y de US1 (necesita una clave guardada para analizar; `ai/schemas.py`, `ai/service.py` y `ai/router.py` ya existen de US1 y se amplían)
- **US3 (Phase 5)**: depende de US2 (amplía `ai/gemini.py`, `ai/service.py`, `pending_analysis_notifier.dart` creados allí)
- **US4 (Phase 6)**: depende de US1 (estado de la clave) y de US2 (los parámetros `aiKeyConfigured`/`onPhoto` de `MealSection` y `_photo` de `DiaryScreen` ya existen de T056–T057)
- **Polish (Phase 7)**: depende de las historias deseadas

### Within Each Story

- Tests antes que implementación, y deben fallar
- Funciones puras (`crypto`, `prompt`, `matching`) → repositorio/proveedor → servicio → ruta → privacidad
- Backend y contrato antes de la app de esa historia

### Parallel Opportunities

- Phase 2: T002, T004, T008, T009, T010, T014, T015 en paralelo; T005, T006, T007 en paralelo tras T004; T011 y T013 en paralelo con las anteriores
- US1: T016–T021 en paralelo; T022, T028 en paralelo
- US2: T036–T043 en paralelo; T044 y T051 en paralelo; T053 en paralelo con T045–T047; T049a en paralelo con T050–T060 (depende solo de T049)
- US3: T061–T065 en paralelo; T068 en paralelo con T066–T067
- US4: T075–T076 en paralelo
- Con varias personas: tras US1, una en US2 (backend) y otra preparando la app de US2 en cuanto T044 esté listo; US3 y US4 solo tras US2

## Parallel Example: User Story 1

```text
Task: "test_ai_key.py"                                    # T016
Task: "test_no_key_in_response.py"                        # T017
Task: "test_user_isolation_ai.py (clave)"                 # T018
Task: "test_ai_contract.py (ai-key)"                       # T020
Task: "ai_key_guide_test.dart"                             # T021
Task: "ai/schemas.py (AiKeyStatus, AiKeyCreate)"            # T022
Task: "models.dart (AiKeyStatus)"                           # T028
```

## Implementation Strategy

### MVP First (solo User Story 1)

1. Phase 1 y Phase 2
2. Phase 3: configurar, sustituir y quitar la clave
3. **Parar y validar**: escenarios 1–5; sin esto no hay nada más que construir (US1 es la base de US2, US3 y US4)
4. US1 por sí sola ya es útil: aunque no se siga con el resto, la app queda lista para el análisis de foto más adelante

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → probar → demo (clave configurada, nunca expuesta)
3. US2 → probar → demo (foto → propuesta → guardado, camino feliz, no bloqueante)
4. US3 → probar → demo (ningún fallo pierde la comida)
5. US4 → probar → demo (la app sirve igual sin clave)
6. Polish y cierre en producción (T080–T084)

## Notes

- [P] = archivos distintos, sin dependencias pendientes
- La etiqueta [Story] enlaza cada tarea con su historia
- Dependencias nuevas: `cryptography` (backend), `image_picker` y `shared_preferences` (app) — research R16
- Los valores nutricionales salen siempre de la base de alimentos (`matched_food`), nunca de la IA (principio II)
- 0 fotos guardadas en el servidor, 0 claves en respuestas ni registros (principio IV, SC-003)
- Commit tras cada tarea o grupo lógico
