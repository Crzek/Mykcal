# Tasks: Base de alimentos, código de barras y alimentos personalizados

**Input**: Design documents from `specs/003-base-de-alimentos/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R18), data-model.md, contracts/ (`api-changes.md`, `search-cases.md`, `ui-flows.md`), quickstart.md

**Tests**: se incluyen. Se sigue la práctica de la 001 y la 002 (test primero) y el principio VI. Los tests de cada historia se escriben antes y deben fallar.

**Organization**: por historia de usuario. Lo común (módulos puros, migración, modelos, errores, guarda de red y base de la app) está en la Phase 2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de `spec.md` (US1 buscar, US2 escanear, US3 personalizados)
- Rutas de backend relativas a `backend/src/mykcal/` salvo que se indique `backend/tests/` o `backend/scripts/`; las de la app, a `app/`.

---

## Phase 1: Setup

- [X] T001 Comprobar que la rama es `003-base-de-alimentos` y que `cd backend && uv run pytest` y `cd app && flutter test` pasan antes de empezar (línea base de la 002)
- [X] T002 [P] En `backend/src/mykcal/config.py` añadir a `Settings`: `off_base_url: str = "https://world.openfoodfacts.org"` (debe empezar por `https://`), `off_user_agent: str = "Mykcal/0.3 (app privada)"` y `off_timeout_s: float = Field(default=5.0, ge=1, le=30)` (R7). Casos nuevos en `backend/tests/unit/test_config.py` (valor por defecto y URL sin `https://` rechazada)

---

## Phase 2: Foundational (bloquea todas las historias)

### Módulos puros (R6, R9, R12)

- [X] T003 [P] Test unitario `backend/tests/unit/test_food_text.py`: `normalize()` pasa a minúsculas, quita tildes y diéresis (`Plátano`→`platano`, `PIÑA`→`pina`, `Jamón`→`jamon`), colapsa espacios, recorta y es idempotente; `"  Arroz   Cocido "`→`"arroz cocido"`
- [X] T004 Crear `backend/src/mykcal/foods/__init__.py` y `backend/src/mykcal/foods/text.py` con `normalize(s: str) -> str` (NFKD, quitar marcas diacríticas, `casefold`, colapsar espacios; R6). Hace pasar T003
- [X] T005 [P] Test unitario `backend/tests/unit/test_gtin.py`: acepta GTIN de 8, 12, 13 y 14 dígitos con dígito de control válido; rechaza longitud distinta, letras y dígito de control erróneo; un UPC-A de 12 dígitos se normaliza a EAN-13 con un `0` delante y el resultado es el mismo para el mismo producto (R9)
- [X] T006 Crear `backend/src/mykcal/foods/gtin.py` con `normalize_gtin(code: str) -> str` (lanza `ValueError` si no es válido) y `is_valid_gtin(code)`. Hace pasar T005
- [X] T007 [P] Test unitario `backend/tests/unit/test_sum_nutrients.py` (R12, FR-016): suma con `Decimal`, escala por cantidad/100, cuenta `None` como 0 y devuelve `incomplete` con los nutrientes que tenían algún `None`; un 0 explícito no marca incompleto (FR-003)
- [X] T008 Crear `backend/src/mykcal/foods/nutrients.py` con: `NUTRIENTS` (los 12 nombres de `TargetValues` de la 002: `kcal, protein_g, carbs_g, fat_g, fiber_g, sodium_mg, potassium_mg, calcium_mg, iron_mg, magnesium_mg, vitamin_d_ug, vitamin_c_mg`), `REQUIRED_NUTRIENTS = (kcal, protein_g, carbs_g, fat_g)`, `MAX_PER_100` con los máximos de `data-model.md` (kcal 900, protein_g 100, carbs_g 100, fat_g 100, fiber_g 100, sodium_mg 40.000, potassium_mg 10.000, calcium_mg 5.000, iron_mg 500, magnesium_mg 2.000, vitamin_d_ug 1.000, vitamin_c_mg 5.000) y `sum_nutrients(items) -> Totals` pura con `Decimal`. Hace pasar T007

### Base de datos

- [X] T009 Crear `backend/alembic/versions/0003_foods.py` (`revision = "0003_foods"`, `down_revision = "0002_onboarding"`, con `downgrade`): `CREATE EXTENSION IF NOT EXISTS pg_trgm` y las tablas de `data-model.md`, constraints verbatim:
  - `food`: `id uuid PK default gen_random_uuid()`, `kind text NOT NULL`, `owner_user_id uuid NULL FK user_account.id`, `name text NOT NULL` (1–120 caracteres), `brand text NULL` (≤ 80), `barcode text NULL`, `base_unit text NOT NULL`, los 12 nutrientes `numeric(8,2)` con `kcal`, `protein_g`, `carbs_g` y `fat_g` `NOT NULL` y los otros ocho `NULL` (= «sin dato»), `CHECK (x >= 0)` en todos y los máximos por 100 de T008, `serving_size numeric(7,2) NULL` con CHECK `> 0 AND <= 5000`, `synonyms text NULL`, `search_text text NOT NULL`, `source text NOT NULL`, `source_code text NULL`, `fetched_at timestamptz NULL`, `archived_at timestamptz NULL`, `deleted_at timestamptz NULL`, `created_at` y `updated_at` `timestamptz NOT NULL`
  - CHECK `ck_food_kind`: `kind IN ('generic','packaged','custom')`; `ck_food_owner`: `(kind = 'custom') = (owner_user_id IS NOT NULL)`; `ck_food_source`: `generic` ↔ `ciqual` con `source_code NOT NULL`, `packaged` ↔ `off` con `barcode` y `fetched_at NOT NULL`, `custom` ↔ `user`; `ck_food_deleted`: `deleted_at IS NULL OR kind = 'custom'`; `ck_food_archived`: `archived_at IS NULL OR kind = 'generic'`; `ck_food_barcode`: `barcode ~ '^[0-9]{8}$|^[0-9]{13,14}$'`; `ck_food_unit`: `base_unit IN ('g','ml')`
  - Índices: único `uq_food_generic_code (source, source_code) WHERE kind = 'generic'`; único `uq_food_packaged_barcode (barcode) WHERE kind = 'packaged'`; único `uq_food_custom_barcode (owner_user_id, barcode) WHERE kind = 'custom' AND deleted_at IS NULL AND barcode IS NOT NULL`; `ix_food_custom_owner (owner_user_id) WHERE kind = 'custom' AND deleted_at IS NULL`; GIN `ix_food_search_trgm (search_text gin_trgm_ops)`
  - `food_import`: `id uuid PK`, `source text NOT NULL`, `edition text NOT NULL`, `sha256 text NOT NULL`, `rows_upserted integer NOT NULL`, `rows_archived integer NOT NULL`, `imported_at timestamptz NOT NULL`
- [X] T010 [P] Crear `backend/src/mykcal/foods/models.py` con `Food` y `FoodImport` (SQLAlchemy 2, mismo estilo que `profile/models.py`) según T009
- [X] T011 Registrar los modelos nuevos donde `backend/alembic/env.py` y `backend/tests/conftest.py` cargan el metadata y añadir a `backend/tests/integration/test_migrate.py` una comprobación de que `0003_foods` sube y baja y de los CHECK: `kind='custom'` sin dueño → error, `kind='generic'` con dueño → error, `deleted_at` en un genérico → error, código `1234567` (7 cifras) → error, `kcal = -1` → error, dos `packaged` con el mismo `barcode` → error, mismo usuario con dos `custom` activos con el mismo código → error pero uno eliminado y otro activo → permitido
- [X] T012 En `backend/src/mykcal/core/errors.py` añadir a `ErrorCode`: `FOOD_NOT_FOUND`, `FOOD_BARCODE_TAKEN` y `FOOD_SOURCE_UNAVAILABLE` (R14, `contracts/api-changes.md`)
- [X] T013 [P] Crear `backend/src/mykcal/foods/schemas.py` con `Nutrients` (los 12 valores, los 8 opcionales `float | None`), `FoodSummary`, `Food`, `FoodSearchResult`, `BarcodeLookup`, `CustomFoodInput` (`extra="forbid"`; `basis: per_100 | per_serving`), `CustomFoodSaved` y `CustomFoodList`, con los campos, tipos y límites de `contracts/api-changes.md` (los decimales salen como número JSON con 2 decimales como máximo)
- [X] T014 Crear `backend/src/mykcal/foods/router.py` con `APIRouter(prefix="/v1/foods")` cuyas rutas dependen de `require_consent` (R14) y, en `backend/src/mykcal/main.py`, incluirlo y añadir a `create_app` el parámetro `off_transport: httpx.AsyncBaseTransport | None = None` guardado en `app.state` (igual que `oidc_transport`). Las rutas las añaden las historias
- [X] T015 [P] En `backend/tests/conftest.py` añadir (FR-018, R18): un *fixture* de sesión `autouse` que hace fallar la prueba si se crea un `httpx.AsyncClient` hacia `openfoodfacts.org` sin `MockTransport`; un helper `user_with_consent` (reutilizar el de la 002 si existe) y un helper `make_user(session, ...)` para crear un segundo usuario. Test mínimo que comprueba que la guarda salta
- [X] T016 Actualizar `specs/001-acceso-y-despliegue/contracts/openapi.yaml` con el «Fragmento OpenAPI» de `specs/003-base-de-alimentos/contracts/api-changes.md` (7 rutas, `components.responses.ValidationError` y `FoodNotFound`, schemas nuevos, `FOOD_*` en el enum de `ErrorBody.code`, `info.version: 0.3.0`)
- [X] T017 [P] En `app/lib/core/api/models.dart` añadir `Nutrients`, `FoodSummary`, `Food`, `FoodKind`, `BarcodeLookup` (con `BarcodeResult found|notFound|incomplete`, `stale`, `productName`, `brand`), `CustomFoodInput` y `CustomFoodSaved` con `fromJson`/`toJson` según `contracts/api-changes.md`; `null` en un nutriente se conserva como «sin dato»
- [X] T018 En `app/lib/core/api/mykcal_api.dart` añadir a `MykcalApi` y a `HttpMykcalApi`: `searchFoods(String q)`, `food(String id)`, `lookupBarcode(String code)`, `customFoods()`, `createCustomFood(CustomFoodInput)`, `updateCustomFood(String id, CustomFoodInput)` y `deleteCustomFood(String id)`. Actualizar los fakes de `app/test/helpers/fakes.dart`. Test de cliente en `app/test/api/foods_api_test.dart` para el mapeo de `FOOD_NOT_FOUND`, `FOOD_BARCODE_TAKEN`, `FOOD_SOURCE_UNAVAILABLE` y `VALIDATION_ERROR` con `fields` (depende de T017)
- [X] T019 [P] Crear `app/lib/features/foods/nutrient_format.dart`: etiqueta y unidad de cada nutriente, `formatNutrient(double?, unit)` que devuelve el texto de «sin dato» cuando es `null` y nunca `0` ni «—» (FR-016), «Por 100 g»/«Por 100 ml» según `baseUnit`, y la etiqueta semántica de cada fila («Vitamina D: sin dato»). Usa `core/format/numbers.dart`. Test en `app/test/foods/nutrient_format_test.dart` (un `0` explícito se muestra «0», un `null` «sin dato»)

**Checkpoint**: T003, T005 y T007 en verde; `alembic upgrade head` y `downgrade -1` funcionan; `flutter test` verde.

---

## Phase 3: User Story 1 — Buscar un alimento genérico (P1) 🎯 MVP

**Goal**: buscar por nombre en la base genérica (CIQUAL traducida), ver el detalle con los valores por 100 g y ofrecer crear uno personalizado si no hay resultados.

**Independent Test**: buscar alimentos habituales («platano», «arroz cocido», «pechuga de pollo») y comprobar que salen con kcal, macros, fibra y micros por 100 g, con «sin dato» donde falte. Pasan al menos 45 de los 50 casos de `contracts/search-cases.md` (SC-001).

### Tests (escribir primero)

- [X] T020 [P] [US1] Test unitario `backend/tests/unit/test_ciqual_cells.py` (R3): `"12,5"`→`12.5`; `"-"` y vacío →`None`; `"traces"`→`0`; `"< 0,5"`→`0`; `"<0,5"`→`0`; texto no reconocido → error; y una fila sin kcal, proteína, carbohidratos o grasa falla nombrando el código CIQUAL
- [X] T021 [P] [US1] Test de integración `backend/tests/integration/test_generic_import.py` (FR-002, R4): con una semilla pequeña de prueba, dos cargas seguidas dejan el mismo número de filas y la segunda registra `generic_import_noop`; cambiar un valor actualiza la fila sin duplicarla; quitar un alimento de la semilla lo archiva (`archived_at`) y deja de salir en la búsqueda; volver a ponerlo lo desarchiva; `food_import` guarda `sha256` y `edition`; un `NULL` de la semilla se queda `NULL` y no `0` (FR-003); dos cargas concurrentes no duplican (bloqueo consultivo)
- [X] T022 [P] [US1] Test de integración `backend/tests/integration/test_search_cases.py` (SC-001): lee la tabla de `specs/003-base-de-alimentos/contracts/search-cases.md`, carga la semilla real `foods/data/generic_foods.csv` y exige ≥ 45 de 50 con un resultado aceptable (nombre normalizado que empieza por un prefijo aceptado) entre los 5 primeros; más los casos extra de ese documento («platano» → primero empieza por «Plátano»; «PLÁTANO» = «Platano» = «platano»; «p» → 400; «xyzzy» → `items: []`). Mientras falte la semilla (T027) se marca `skip` con el motivo
- [X] T023 [P] [US1] Test de integración `backend/tests/integration/test_search_order.py` (R6, FR-005): con datos de prueba, el orden es personalizados del usuario → genéricos → envasados; dentro de cada tipo, nombre exacto → empieza por la consulta → una palabra empieza por la consulta → resto; empate por nombre más corto; máximo 20; los archivados y los personalizados de otro usuario no salen; `is_mine` es `true` solo en los propios
- [X] T024 [P] [US1] Test de contrato `backend/tests/contract/test_foods_contract.py` para `GET /v1/foods/search` y `GET /v1/foods/{food_id}` contra `openapi.yaml` (patrón de `test_onboarding_contract.py`), y de integración del detalle: un genérico devuelve los 12 valores con `null` donde no hay dato y `serving_size`; un id inexistente → `404 FOOD_NOT_FOUND`

### Implementación

- [X] T025 [US1] Crear `backend/data/ciqual/ciqual_es.csv` con cabecera `ciqual_code;name_es;synonyms` y una primera selección de ~600 alimentos habituales en España, en español y sin dejar fuera ninguno de los 50 de `contracts/search-cases.md`; los nombres empiezan por el alimento («Plátano, crudo», «Arroz, cocido») y los sinónimos van separados por `|` (R2). Erick la revisa (plan, «Puntos a confirmar» 2)
- [X] T026 [US1] Crear `backend/src/mykcal/foods/ciqual.py` (lectura pura de celdas, R3: hace pasar T020) y `backend/scripts/build_generic_seed.py` (uso: `python scripts/build_generic_seed.py <carpeta_ciqual> <ciqual_es.csv> <salida.csv>`) que lee los ficheros oficiales de CIQUAL (kcal de «Énergie, Règlement UE N° 1169/2011 (kcal/100 g)», carbohidratos de «Glucides (g/100 g)», más proteína, grasa, fibra y los 7 micros), los une con el CSV curado y escribe `backend/src/mykcal/foods/data/generic_foods.csv` con la cabecera de edición de CIQUAL; falla si un código curado no existe en CIQUAL o si le falta kcal o macros
- [X] T027 [US1] Generar `backend/src/mykcal/foods/data/generic_foods.csv` con el script de T026 a partir de los ficheros de CIQUAL descargados a mano fuera de git (`quickstart.md` §0). **Bloqueada** hasta que Erick confirme la licencia de la edición 2025 y descargue los ficheros (R1); si no, usar CIQUAL 2020. Al terminar, quitar el `skip` de T022
- [X] T028 [US1] Crear `backend/src/mykcal/foods/load_generic.py` (R4): lee la semilla, calcula el SHA-256, lo compara con el último de `food_import` (`source = 'ciqual'`), hace *upsert* por `(source, source_code)` calculando `search_text = normalize(name + brand + synonyms)`, archiva los genéricos que ya no están, usa el bloqueo consultivo de `mykcal.migrate`, registra `generic_import_done`/`generic_import_noop` con hash y número de filas y se puede lanzar con `python -m mykcal.foods.load_generic`. Hace pasar T021
- [X] T029 [US1] En `backend/docker-entrypoint.sh` lanzar `python -m mykcal.foods.load_generic` después de las migraciones (respetando `RUN_MIGRATIONS`) y comprobar en `backend/Dockerfile` que `src/mykcal/foods/data/` entra en la imagen
- [X] T030 [US1] Crear `backend/src/mykcal/foods/repository.py` con `search(session, user_id, q_norm, limit=20)` (filtro `search_text LIKE '%q%'` o `q <% search_text`; solo genéricos y envasados no archivados y personalizados propios con `deleted_at IS NULL`; orden de R6) y `get_visible(session, user_id, food_id)` (genérico, envasado o personalizado propio no eliminado). Toda función de personalizados recibe `user_id` (principio V)
- [X] T031 [US1] Crear `backend/src/mykcal/foods/service.py` con `search_foods` (normaliza; menos de 2 caracteres → `ApiError(400, VALIDATION_ERROR, fields=["q"])`; `ApiError(404, FOOD_NOT_FOUND)` si `get_visible` no encuentra) y el mapeo a `FoodSummary` y `Food`
- [X] T032 [US1] En `backend/src/mykcal/foods/router.py` implementar `GET /v1/foods/search` y `GET /v1/foods/{food_id}` (`food_id: UUID`). Registrar `food_search` con `result_count` y `duration_ms` **sin la consulta** (R15). Hacen pasar T022, T023 y T024
- [X] T033 [P] [US1] Textos de la historia en `app/lib/l10n/app_es.arb` (y regenerar `app_localizations*.dart`) según `contracts/ui-flows.md` pantallas 1 y 2: título «Alimentos», «Escanear código de barras», «Escribe al menos 2 letras», «Buscando…», «No hemos encontrado “{q}”.», «Crear alimento “{q}”», secciones «Mis alimentos»/«Alimentos»/«Productos envasados», «Mío», «Tuyo», «Ración del envase», «sin dato», «Los nutrientes sin dato cuentan como 0 en los totales.», «Datos de una copia de más de 30 días», «Sin conexión. Inténtalo de nuevo.» y «Reintentar»
- [X] T034 [US1] Crear `app/lib/features/foods/food_search_controller.dart` (Riverpod): espera 300 ms tras la última tecla, no busca con menos de 2 caracteres, descarta la respuesta de una consulta antigua, conserva lo escrito sin conexión y expone estados cargando/vacío/error/resultados agrupados por tipo
- [X] T035 [US1] Crear `app/lib/features/foods/food_search_screen.dart` según `contracts/ui-flows.md` pantalla 1: `TextField` con autofocus y botón limpiar, secciones, `LinearProgressIndicator` con anuncio, estado vacío con «Crear alimento “{q}”» (callback `onCreate(name)`, la navegación la conecta T065) y botón de escáner (callback `onScan`, lo conecta T049). Etiqueta semántica por fila: «{nombre}, {marca}, {kcal} kilocalorías por 100 gramos[, tuyo]»; objetivos táctiles ≥ 48 dp
- [X] T036 [US1] Crear `app/lib/features/foods/food_detail_screen.dart` según pantalla 2: cabecera con tipo y fuente, marca, código, ración, tabla «Por 100 g/ml» con `nutrient_format.dart`, «sin dato» en las filas vacías con `Semantics` por fila, aviso al pie si falta fibra o algún micro, aviso de copia antigua si `stale`, y `✎` solo si `isMine` (callback `onEdit`, lo conecta T065)
- [X] T037 [US1] Añadir el botón «Alimentos» en `app/lib/features/home/home_screen.dart` que abre `FoodSearchScreen`
- [X] T038 [P] [US1] Tests de widgets y accesibilidad en `app/test/foods/food_search_screen_test.dart` y `app/test/foods/food_detail_screen_test.dart`, con `MykcalApi` sustituida: menos de 2 letras no llama a la API; el *debounce* hace una sola llamada; una respuesta antigua no pisa la nueva; «sin resultados» ofrece crear con el nombre escrito; «sin dato» se lee como tal; sin conexión conserva el texto; semántica de las filas; texto al 200 % sin desbordes; `flutter_test` `meetsGuideline` de contraste y tamaño táctil. Añadir `app/test/home/home_menu_test.dart` con el botón «Alimentos»

**Checkpoint**: US1 funcional con la semilla real: «platano» devuelve «Plátano, crudo» y SC-001 pasa.

---

## Phase 4: User Story 2 — Escanear un código de barras (P1)

**Goal**: obtener un producto envasado por código con valores por 100 g/ml y ración, con copia local compartida de 30 días y alternativa de crear un personalizado si no existe o está incompleto.

**Independent Test**: escanear (o teclear) un código ya consultado, uno nuevo, uno desconocido y uno sin macros, y comprobar cada resultado; sin permiso de cámara, introducir el código a mano.

### Tests (escribir primero)

- [X] T039 [P] [US2] Crear *fixtures* de Open Food Facts en `backend/tests/fixtures/off/`: `found_grams.json` (producto en g con ración), `found_ml.json` (bebida con `product_quantity_unit: "ml"` y ración), `kj_only.json` (solo `energy-kj_100g`), `no_macros.json` (`status: 1` sin kcal ni macros), `not_found.json` (`status: 0`) y `no_name.json`. Basadas en respuestas reales recortadas a los campos de R7; sin datos personales
- [X] T040 [P] [US2] Test unitario `backend/tests/unit/test_off_mapping.py` (R8): conversión g→mg (×1.000) de sodio, potasio, calcio, hierro, magnesio y vitamina C; vitamina D g→µg (×1.000.000); kJ→kcal (`/ 4,184`); campo ausente → `None`; redondeo a 2 decimales `ROUND_HALF_UP`; `base_unit` `ml` si `product_quantity_unit` es `ml`/`cl`/`l`; ración solo si `serving_quantity > 0`; nombre `product_name_es` → `product_name` → «Producto sin nombre»; y `incomplete` cuando falta alguno de kcal, proteína, carbohidratos o grasa
- [X] T041 [P] [US2] Test de integración `backend/tests/integration/test_barcode_lookup.py` con `httpx.MockTransport` (R9, R7, FR-018): personalizado propio gana a la copia local y a OFF (US3.6); copia ≤ 30 días se sirve sin llamar a OFF (el transporte no recibe petición); sin copia → OFF `found` crea la copia con `fetched_at`; segunda consulta de otro usuario no llama a OFF; copia de más de 30 días → renueva desde OFF; copia caducada y OFF caído → `found` con `stale: true`; sin copia y OFF caído (timeout, red, 5xx) → `503 FOOD_SOURCE_UNAVAILABLE`; `status: 0` → `not_found` con el código normalizado; sin macros → `incomplete` con `product_name` y `brand` y sin guardar la copia (US2.4); UPC-A de 12 dígitos → misma clave EAN-13; código con dígito de control mal → `400 VALIDATION_ERROR` con `fields: ["code"]`; el personalizado de otro usuario con ese código no se devuelve. Cada `not_found` e `incomplete` devuelve el código para crear un personalizado (SC-003)
- [X] T042 [P] [US2] Añadir a `backend/tests/contract/test_foods_contract.py` el contrato de `GET /v1/foods/barcode` contra `openapi.yaml` para `found`, `not_found`, `incomplete` y `503`

### Implementación

- [X] T043 [US2] Crear `backend/src/mykcal/foods/off_client.py` (R7, R8): función pura `map_product(payload) -> OffResult` (`found | incomplete | not_found`) con `Decimal` y la tabla de conversión de R8, y `OffClient` sobre `httpx.AsyncClient` con `GET {off_base_url}/api/v2/product/{code}`, `fields=code,product_name,product_name_es,brands,nutriments,serving_quantity,serving_quantity_unit,product_quantity_unit`, cabecera `User-Agent` de `off_user_agent`, tiempo máximo `off_timeout_s`, sin reintentos y transporte inyectable. Red, tiempo agotado y 5xx → `OffUnavailable`. Hace pasar T040
- [X] T044 [US2] Ampliar `backend/src/mykcal/foods/repository.py` con `get_custom_by_barcode(session, user_id, code)`, `get_packaged_by_barcode(session, code)` y `upsert_packaged(session, mapped, now)` (clave `uq_food_packaged_barcode`, `fetched_at = now`, `search_text` normalizado)
- [X] T045 [US2] Ampliar `backend/src/mykcal/foods/service.py` con `lookup_barcode(session, user_id, code, off, now)` siguiendo R9: `normalize_gtin` → personalizado propio → copia con `fetched_at` ≤ 30 días → OFF; copia caducada con OFF caído o sin el producto → `found` con `stale: true`; sin copia y OFF caído → `ApiError(503, FOOD_SOURCE_UNAVAILABLE)`; los no encontrados no se guardan. El reloj es `mykcal.clock`
- [X] T046 [US2] En `backend/src/mykcal/foods/router.py` implementar `GET /v1/foods/barcode?code=` (el código en la query, R9) construyendo el `OffClient` con `app.state.off_transport`. Registrar `barcode_lookup` con `result` (`custom|cache|off_found|off_not_found|off_incomplete|off_error|stale`) y `duration_ms` **sin el código** (R15). Hacen pasar T041 y T042
- [X] T047 [US2] En `app/pubspec.yaml` añadir `mobile_scanner: ^7` y ejecutar `flutter pub get`; en `app/android/app/src/main/AndroidManifest.xml` añadir `<uses-permission android:name="android.permission.CAMERA"/>` y `<uses-feature android:name="android.hardware.camera" android:required="false"/>`; comprobar que `minSdk` es ≥ 23 y que el modelo de ML Kit queda incluido en el APK (R13). Comprobar con `flutter build apk --debug --flavor dev` que compila
- [X] T048 [P] [US2] Crear `app/lib/features/foods/gtin.dart` con el mismo algoritmo que `backend/src/mykcal/foods/gtin.py` (R9) y su test `app/test/foods/gtin_test.dart` con los mismos casos que T005
- [X] T049 [P] [US2] Textos de la historia en `app/lib/l10n/app_es.arb` según `contracts/ui-flows.md` pantalla 3: «Escanear», «Apunta al código de barras del envase», «Introducir el código a mano», «Código de barras (8 a 14 cifras)», «Revisa el código: no es válido», «Buscando producto…», «No conocemos este producto.», «{nombre} no tiene información nutricional suficiente.», «Crear alimento con este código», «No hemos podido consultar la base de productos.», «Mykcal usa la cámara solo para leer códigos de barras. No guarda fotos.», «Permitir cámara», «Puedes activarlo en Ajustes del sistema → Aplicaciones → Mykcal → Permisos.», «Linterna»
- [X] T050 [US2] Crear `app/lib/features/foods/barcode_scan_screen.dart` con `mobile_scanner` (R13): formatos `ean13`, `ean8`, `upcA`, `upcE`; al primer código válido vibra, detiene la cámara y llama a `lookupBarcode`; sin permiso muestra la explicación con «Permitir cámara» e «Introducir el código a mano»; con permiso denegado para siempre muestra el texto de ajustes del sistema en lugar del botón; linterna si el móvil la tiene; el `MobileScannerController` se recibe por parámetro para poder simularlo
- [X] T051 [US2] Crear `app/lib/features/foods/barcode_manual_dialog.dart` (campo numérico con etiqueta «Código de barras (8 a 14 cifras)», error junto al campo si `gtin.dart` lo rechaza antes de llamar al servidor, `[ Buscar ]`) y `app/lib/features/foods/barcode_result_flow.dart` que muestra el resultado: `found` → `FoodDetailScreen`; `not_found` e `incomplete` → hoja con «Crear alimento con este código» (callback `onCreate(code, name?, brand?)`, lo conecta T065); `FOOD_SOURCE_UNAVAILABLE` → hoja con «Reintentar» y «Crear alimento»; sin conexión → «Sin conexión…» con «Reintentar»
- [X] T052 [US2] Conectar el botón de escáner de `food_search_screen.dart` (T035) con `BarcodeScanScreen` y `BarcodeManualDialog`
- [X] T053 [P] [US2] Tests de widgets en `app/test/foods/barcode_scan_screen_test.dart` y `app/test/foods/barcode_result_flow_test.dart` con el controlador y la API simulados: código leído → una sola llamada y cámara detenida; permiso denegado → explicación y entrada manual; denegado para siempre → texto de ajustes; los cuatro resultados y el 503; código inválido no llama a la API; semántica y texto al 200 %

**Checkpoint**: US1 y US2 funcionan; un producto escaneado dos veces se sirve de la copia local.

---

## Phase 5: User Story 3 — Crear y gestionar alimentos personalizados (P2)

**Goal**: crear, ver, buscar, editar y eliminar alimentos propios, con valores por 100 o por ración, validación y aviso de kcal, visibles solo para su dueño.

**Independent Test**: crear un alimento personalizado en menos de 1 minuto, encontrarlo, editarlo y eliminarlo, y comprobar que otro usuario nunca lo ve ni por búsqueda, ni por código ni por id.

### Tests (escribir primero)

- [X] T054 [P] [US3] Test unitario `backend/tests/unit/test_custom_rules.py` (R10, FR-013, FR-014): conversión por ración (`480 kcal` en `150 g` → `320`; `ROUND_HALF_UP` a 2 decimales); `per_serving` sin `serving_size` → error en `serving_size`; valor negativo → error; `protein_g + carbs_g + fat_g + fiber_g > 100` → error en los cuatro campos; un valor por encima de su máximo de T008 → error en ese campo; nombre vacío, solo espacios y de 121 caracteres → error; marca de 81 → error; código no válido → error en `barcode`; `KCAL_MISMATCH` justo en el límite (15 % exacto no avisa, por encima sí; calculadas 0 con kcal > 0 avisa); fibra y micros ausentes → `None`
- [X] T055 [P] [US3] Test de integración `backend/tests/integration/test_custom_foods.py`: crear con los 4 obligatorios (201, `warnings: []`); crear por ración guarda los valores por 100 y la ración; aparece en `GET /v1/foods/search` con `is_mine: true` y antes que un genérico con el mismo nombre (US3.3); `GET /v1/foods/custom` lista por nombre; editar cambia lo mostrado; eliminar es lógico (`deleted_at`): desaparece de búsqueda, de la lista, del código de barras y del detalle (`404`); código repetido del mismo usuario → `409 FOOD_BARCODE_TAKEN` (también al editar, pero no contra sí mismo); tras eliminar se puede reutilizar el código; con código, `GET /v1/foods/barcode` devuelve el personalizado antes que OFF; `KCAL_MISMATCH` devuelve `warnings` y guarda igualmente; errores con `fields`, nunca valores; editar o eliminar no cambia lo ya copiado (FR-015, comprobado sobre la fila `Food` copiada en la prueba)
- [X] T056 [P] [US3] Test de privacidad `backend/tests/privacy/test_user_isolation_foods.py` (SC-004, marcador `privacy`/`isolation`): el usuario B no ve el personalizado de A por búsqueda (mismo nombre), por código de barras, por `GET /v1/foods/{id}`, por `GET /v1/foods/custom`, y recibe `404 FOOD_NOT_FOUND` idéntico (mismo cuerpo que un id inexistente) al intentar `PUT` y `DELETE`; B puede crear un personalizado con el mismo nombre y el mismo código que A sin conflicto
- [X] T057 [P] [US3] Añadir a `backend/tests/contract/test_foods_contract.py` el contrato de `GET/POST /v1/foods/custom` y `PUT/DELETE /v1/foods/custom/{food_id}` contra `openapi.yaml`

### Implementación

- [X] T058 [US3] Crear `backend/src/mykcal/foods/custom_rules.py` con funciones puras (R10): `to_per_100(input) -> Nutrients` (conversión por ración con `Decimal`), `validate(input) -> list[str]` (nombres de campo inválidos), `kcal_mismatch(n) -> bool` (`|kcal − (4P + 4C + 9G)| / (4P + 4C + 9G) > 0,15`). Hace pasar T054
- [X] T059 [US3] Ampliar `backend/src/mykcal/foods/repository.py` con `create_custom`, `update_custom`, `soft_delete_custom` y `list_custom`, todas con `user_id` obligatorio y filtrando `kind = 'custom' AND owner_user_id = :user_id AND deleted_at IS NULL`; `search_text = normalize(nombre + marca)`; traducir la violación de `uq_food_custom_barcode` a un error propio
- [X] T060 [US3] Ampliar `backend/src/mykcal/foods/service.py` con `create_custom`, `update_custom`, `delete_custom` y `list_custom`: validar con `custom_rules` (`ApiError(400, VALIDATION_ERROR, fields=…)`), convertir, normalizar el código con `normalize_gtin`, devolver `warnings` y mapear el choque de código a `ApiError(409, FOOD_BARCODE_TAKEN)`; un id ajeno, eliminado o inexistente → `ApiError(404, FOOD_NOT_FOUND)` (R14)
- [X] T061 [US3] En `backend/src/mykcal/foods/router.py` implementar `GET`/`POST /v1/foods/custom` y `PUT`/`DELETE /v1/foods/custom/{food_id}` (declarar `/custom` antes de `/{food_id}`). Registrar `custom_food_saved` y `custom_food_deleted` solo con el `id` (R15). Hacen pasar T055, T056 y T057
- [X] T062 [P] [US3] Crear `app/lib/features/foods/custom_food_check.dart` (puro, R10): mismas reglas y mensajes que el backend (obligatorio, negativo, máximo por 100, suma > 100, ración obligatoria con «Por ración», código no válido con `gtin.dart`), conversión a «= X kcal por 100 g» y `kcalMismatch`. Test `app/test/foods/custom_food_check_test.dart` con los mismos casos que T054
- [X] T063 [P] [US3] Textos de la historia en `app/lib/l10n/app_es.arb` según `contracts/ui-flows.md` pantallas 4 y 5: «Nuevo alimento», «Editar alimento», campos y unidades, «Por 100 g», «Por ración», «Fibra y micronutrientes (opcional)», todos los mensajes de validación de la tabla, aviso «Las kcal no cuadran con los macros (calculadas: {n} kcal)», «= {n} kcal por 100 g», «Ya tienes un alimento con este código», «¿Descartar los cambios?», «Mis alimentos», «Aún no has creado alimentos.», «¿Eliminar “{nombre}”? Las comidas ya registradas no cambian.»
- [X] T064 [US3] Crear `app/lib/features/foods/custom_food_form_screen.dart` según pantalla 4: campos nombre, marca, código (precargable), unidad, «Por 100 g/ml» o «Por ración» con ración, 4 obligatorios y `ExpansionTile` con los 8 opcionales; errores bajo cada campo y anunciados; aviso de kcal en vivo con icono, texto y `liveRegion` que no bloquea; equivalente por 100 bajo cada valor con «Por ración»; sin conexión conserva todo; confirma al salir con cambios; al guardar vuelve al detalle. Parámetros `initialName`, `initialBarcode`, `initialBrand` y `existing` para editar. Con solo los 5 campos y por 100 g, se crea en menos de 1 min (SC-005)
- [X] T065 [US3] Crear `app/lib/features/foods/my_foods_screen.dart` según pantalla 5 (lista, menú `⋮` con «Editar» y «Eliminar» con diálogo, vacío con «Crear alimento», FAB con etiqueta «Crear alimento») y conectar los callbacks pendientes: `onCreate` de la búsqueda (T035) y del flujo de códigos (T051) abren el formulario con nombre, código y marca precargados; `onEdit` del detalle (T036) abre el formulario en edición; el botón «Mis alimentos» de la búsqueda abre esta lista
- [X] T066 [P] [US3] Tests de widgets y accesibilidad en `app/test/foods/custom_food_form_screen_test.dart` y `app/test/foods/my_foods_screen_test.dart`: errores junto al campo; aviso de kcal en vivo sin bloquear; «Por ración» muestra el equivalente y exige ración; `FOOD_BARCODE_TAKEN` bajo Código; sin conexión conserva lo escrito; diálogo de eliminar; precarga desde el escáner; semántica, texto al 200 % y contraste

**Checkpoint**: las tres historias funcionan de forma independiente.

---

## Phase 6: Polish & cross-cutting

- [X] T067 [P] Añadir todas las rutas de `/v1/foods/**` (siete) a `HEALTH_DATA_ROUTES` de `backend/tests/privacy/test_consent_gate.py` y comprobar que sin consentimiento responden `403 CONSENT_REQUIRED` sin escribir nada
- [X] T068 [P] Ampliar `backend/tests/privacy/test_all_routes_require_identity.py` para que cubra las rutas nuevas (sin identidad → 401) y compruebe que `PUBLIC_ROUTES` no ha cambiado
- [X] T069 [P] Ampliar `backend/tests/privacy/test_logs_no_secrets.py` (R15, principio X): buscar «chorizo», escanear un código conocido, crear y borrar un personalizado y lanzar la importación no dejan en los registros ni la consulta, ni el código, ni el nombre del alimento, ni valores nutricionales
- [X] T070 [P] Crear `app/lib/features/settings/data_sources_screen.dart` y la entrada «Fuentes de datos» en `app/lib/features/settings/settings_screen.dart` con los dos textos de atribución de R16 (CIQUAL con su edición y Open Food Facts bajo ODbL) y las direcciones web como texto seleccionable, sin `url_launcher`; textos en `app_es.arb`; test en `app/test/settings/data_sources_screen_test.dart`
- [X] T071 [P] Crear `backend/src/mykcal/foods/data/FUENTES.md` con la atribución «Anses. Table de composition nutritionnelle des aliments Ciqual», la edición, la licencia y la nota de que los nombres están traducidos y la selección es de Mykcal (R16)
- [X] T072 [P] Documentar `OFF_USER_AGENT`, `OFF_BASE_URL` y `OFF_TIMEOUT_S` en `docs/deploy/produccion.md` y en `specs/001-acceso-y-despliegue/contracts/dokploy-setup.md` (opcionales; recomendar incluir un contacto en el valor), y que la importación genérica y la migración se ejecutan al arrancar
- [X] T073 [P] Enlazar las pantallas de la 003 desde `specs/001-acceso-y-despliegue/contracts/ui-flows.md` (como se hizo con el onboarding de la 002)
- [X] T074 Actualizar la restricción técnica «Alimentos» de `.specify/memory/constitution.md` («BEDCA, licencia a verificar» → «CIQUAL (ANSES, Licence Ouverte) traducida») con `/speckit-constitution` como PATCH y con la aprobación de Erick, junto con el informe de impacto (plan, «Puntos a confirmar» 4)
- [X] T075 `cd backend && uv run ruff check && uv run pytest` y `cd app && flutter analyze && flutter test`: todo en verde, sin tests omitidos (en particular T022 ya sin `skip`) y sin ninguna llamada real a Open Food Facts (guarda de T015)
- [ ] T076 Ejecutar los 20 escenarios de `quickstart.md` §4 contra el backend local con la semilla real, con TalkBack y texto al 200 % en las pantallas 1–5, y anotar cualquier desviación. **Hecho en automático**: escenarios 1–4, 6, 9, 11–17 (tests de integración, contrato y privacidad) y §2 del quickstart (migración, importación dos veces → `generic_import_done` y `generic_import_noop`, `downgrade -1` quita `pg_trgm`). **Probado en el móvil (Erick, 2026-11-24, APK contra backend local)**: búsqueda de genéricos, lectura de un código de barras real (ficha con macros y micros) y creación de un alimento personalizado (KitKat) con marca, macros, micros, gramos y calorías; todo correcto. **Pendiente en el móvil**: escenarios 7 (sin red), 10 (permiso de cámara denegado) y 18–20 (TalkBack y texto al 200 %)
- [ ] T077 Tras fusionar `dev` en `main` y desplegar en Dokploy (principio IX), repetir en el móvil contra producción los escenarios 1, 5, 8 y 11 de `quickstart.md` y comprobar en los registros `generic_import_done` o `generic_import_noop`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Setup y **bloquea** las historias. Dentro de ella: T003→T004, T005→T006, T007→T008 (test antes que código); T009→T010→T011; T012, T013 tras T008; T014 tras T012–T013; T016 tras T013; T017→T018; T019 tras T017.
- **US1, US2 y US3**: dependen solo de la Phase 2.
  - US2 usa el detalle (T036) y la ruta base de US1; si se trabaja por separado, basta con tener los módulos puros y el repositorio de T030.
  - US3 conecta navegación con las pantallas de US1 y US2 (T065); el backend de US3 es independiente.
  - El orden recomendado es el de prioridad: US1 → US2 → US3.
- **Polish (Phase 6)**: depende de las historias que se quieran entregar; T077 depende de que `main` esté desplegada.

### Dependencias dentro de las historias

- Tests antes que el código que los hace pasar (T020–T024 → T025–T032; T039–T042 → T043–T046; T054–T057 → T058–T061).
- Modelos → repositorio → servicio → router → app.
- T027 (semilla real) está bloqueada por la licencia de CIQUAL y los ficheros descargados por Erick (R1); mientras, el resto de US1 avanza con datos de prueba y T022 queda en `skip`.
- T035, T036 y T051 dejan *callbacks* que conecta T065; mientras no esté US3, el botón de crear no hace nada o está oculto.

### Oportunidades de paralelismo

- Phase 2: T003, T005, T007, T010, T013, T015, T017 y T019 son independientes entre sí (tras sus tests).
- US1: T020–T024 en paralelo; T033 y T038 en paralelo con el backend.
- US2: T039–T042 en paralelo; T048 y T049 en paralelo con T043–T046.
- US3: T054–T057 en paralelo; T062 y T063 en paralelo con T058–T061.
- Con dos personas, una puede llevar el backend (T003–T016, T020–T032, T043–T046, T058–T061) y otra la app (T017–T019, T033–T038, T047–T053, T062–T066) usando `contracts/api-changes.md` como acuerdo.

### Ejemplo de paralelismo: US1

```text
Task: "Test unitario test_ciqual_cells.py"                (T020)
Task: "Test de integración test_generic_import.py"        (T021)
Task: "Test de integración test_search_cases.py"          (T022)
Task: "Test de integración test_search_order.py"          (T023)
Task: "Test de contrato búsqueda y detalle"               (T024)
```

## Implementation Strategy

### MVP primero (solo US1)

1. Phase 1 y Phase 2.
2. Phase 3 (US1): buscar y ver alimentos genéricos.
3. **Parar y validar**: escenarios 1–4 de `quickstart.md` y SC-001.
4. Es usable en el móvil: la base genérica ya sirve a la 004 para registrar a mano.

### Entrega incremental

1. Base lista → US1 (MVP) → validar.
2. US2: escaneo y copia local → validar escenarios 5–10.
3. US3: personalizados → validar escenarios 11–17 y SC-004.
4. Polish → cierre con `dev` → `main` y T077.

### Recorte si el plazo aprieta (constitución)

US3 es P2: US1 y US2 ya cubren la mayoría de casos. Si hace falta recortar, US3 se pospone, pero conservando el ofrecimiento de «Crear alimento» como texto informativo hasta que exista (SC-003 exige que no se pierda el código no encontrado).

## Notes

- [P] = archivos distintos y sin dependencias pendientes.
- La etiqueta [Story] enlaza cada tarea con su historia para la trazabilidad.
- Confirmar que los tests fallan antes de implementar.
- Hacer commit tras cada tarea o grupo lógico, en la rama `003-base-de-alimentos`.
- Hasta que Erick confirme la licencia de CIQUAL y descargue los ficheros, T027 no se puede hacer; el resto del trabajo no se detiene.
