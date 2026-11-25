# Tasks: Registro rápido (recientes, favoritos y copiar comidas)

**Input**: Design documents from `specs/005-registro-rapido/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R14), data-model.md, contracts/ (`api-changes.md`, `quick-cases.md`, `ui-flows.md`), quickstart.md

**Tests**: se incluyen. Se sigue la práctica de la 001–004 (test primero) y el principio VI. Los tests de cada historia se escriben antes y deben fallar.

**Organization**: por historia de usuario. Lo común (migración, modelos, errores, esquemas, contrato y base de la app) está en la Phase 2. US1 (recientes) y US2 (favoritos) comparten la pantalla de añadir; US3 (copiar) es independiente de las dos.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de `spec.md` (US1 añadir desde recientes, US2 favoritos, US3 copiar una comida de otro día)
- Rutas de backend relativas a `backend/src/mykcal/` salvo que se indique `backend/tests/` o `backend/alembic/`; las de la app, a `app/`.

---

## Phase 1: Setup

- [X] T001 Comprobar que la rama es `005-registro-rapido` y que `cd backend && uv run ruff check && uv run pytest` y `cd app && flutter analyze && flutter test` pasan antes de empezar (línea base de la 004)

---

## Phase 2: Foundational (bloquea todas las historias)

### Base de datos y modelos (R1, R4, R8)

- [X] T002 [P] Añadir a `backend/tests/integration/test_migrate.py` los casos de `0005_quick` (suben y bajan): `favorite_food` con la misma pareja `(user_id, food_id)` dos veces → error (PK); `favorite_food.user_id` o `food_id` inexistente → error (FK); `diary_entry.copy_id` es `NULL` en las filas existentes; `downgrade -1` elimina `favorite_food` y `diary_entry.copy_id`
- [X] T003 Crear `backend/alembic/versions/0005_quick.py` (`revision = "0005_quick"`, `down_revision = "0004_diary"`, con `downgrade`), constraints verbatim de `data-model.md`:
  - Tabla `favorite_food`: `user_id uuid NOT NULL FK user_account.id`, `food_id uuid NOT NULL FK food.id`, `created_at timestamptz NOT NULL`; **PK `(user_id, food_id)`**
  - `diary_entry.copy_id uuid NULL` (sin `server_default`: las filas existentes quedan en `NULL`)
  - Índice parcial `ix_diary_entry_copy (user_id, copy_id) WHERE copy_id IS NOT NULL`
  - Hace pasar T002
- [X] T004 [P] Crear `backend/src/mykcal/quick/__init__.py` y `backend/src/mykcal/quick/models.py` con `FavoriteFood` (SQLAlchemy 2, mismo estilo que `diary/models.py`) según T003, y registrarlo donde `backend/alembic/env.py` y `backend/tests/conftest.py` cargan el metadata
- [X] T005 [P] En `backend/src/mykcal/diary/models.py` añadir `copy_id: Mapped[uuid.UUID | None]` (`UUID(as_uuid=True)`, `nullable=True`) y el índice parcial `ix_diary_entry_copy` de T003 a `__table_args__`
- [X] T006 En `backend/src/mykcal/core/errors.py` añadir a `ErrorCode`: `COPY_SOURCE_EMPTY` (400) y `COPY_NOT_FOUND` (404, mismo cuerpo para copia inexistente, ajena, ya deshecha o fuera de plazo) (R10)

### Esquemas, rutas y contrato

- [X] T007 [P] Crear `backend/src/mykcal/quick/schemas.py` con `QuickFood` (`food: foods.schemas.Food`, `suggested_quantity: float` > 0 y ≤ 10000, `suggested_servings: float | None` > 0 y ≤ 100, `last_used_at: datetime | None`, `is_favorite: bool`) y `QuickFoodList` (`items: list[QuickFood]`), según `contracts/api-changes.md`
- [X] T008 Crear `backend/src/mykcal/quick/router.py` con `APIRouter()` cuyas rutas dependen de `require_consent` (R10) y, en `backend/src/mykcal/main.py`, incluirlo **antes** que `foods_router`: si no, `GET /v1/foods/{food_id}` captura `recent` y `favorites` y responde 422. Las rutas las añaden las historias
- [X] T009 Actualizar `specs/001-acceso-y-despliegue/contracts/openapi.yaml` con el «Fragmento OpenAPI» de `specs/005-registro-rapido/contracts/api-changes.md`: 7 rutas (`/v1/foods/recent`, `/v1/foods/favorites`, `PUT`/`DELETE /v1/foods/favorites/{food_id}`, `/v1/diary/copy-sources`, `POST /v1/diary/copies`, `DELETE /v1/diary/copies/{copy_id}`), respuesta `QuickFoodListOk`, schemas `QuickFood`, `QuickFoodList`, `CopySourceEntry`, `CopySourceMeal`, `CopySourceDay`, `CopySourceList`, `DiaryCopyCreate` y `DiaryCopyResult`, cabecera `Location` en el `201` de `POST /v1/diary/entries`, `COPY_SOURCE_EMPTY` y `COPY_NOT_FOUND` en el enum de `ErrorBody.code`, `info.version: 0.5.0`
- [X] T010 (depende de T004 y T005) En `backend/tests/conftest.py` añadir `make_favorite(user, food, created_at=None)` que inserta una `FavoriteFood`, y el parámetro `copy_id=None` y `created_at=None` a `make_entry` (los recientes ordenan por `created_at`)

### Base de la app

- [X] T011 [P] En `app/lib/core/api/models.dart` añadir `QuickFood` (`food: Food`, `suggestedQuantity: double`, `suggestedServings: double?`, `lastUsedAt: DateTime?`, `isFavorite: bool`), `CopySourceEntry`, `CopySourceMeal` (con `valuesChanged`), `CopySourceDay` y `DiaryCopyResult` (`copyId`, `entryIds`, `day: DiaryDay`) con `fromJson` según `contracts/api-changes.md`
- [X] T012 En `app/lib/core/api/mykcal_api.dart` añadir a `MykcalApi` y a `HttpMykcalApi`: `recentFoods()`, `favoriteFoods()`, `addFavorite(String foodId)`, `removeFavorite(String foodId)`, `copySources(DateTime targetDate, Meal targetMeal)`, `copyMeal(...)` (con `utc_offset_min`) y `undoCopy(String copyId, DateTime date, int utcOffsetMin)`. Cambiar `addEntry` para devolver también el id de la entrada creada leyendo la cabecera `Location` (R3), p. ej. un `AddedEntry { DiaryDay day, String entryId }`, y actualizar sus usos y los fakes de `app/test/helpers/fakes.dart`. Test de cliente en `app/test/api/quick_api_test.dart` para el mapeo de `COPY_SOURCE_EMPTY`, `COPY_NOT_FOUND`, `FOOD_NOT_FOUND`, `DIARY_DATE_OUT_OF_RANGE` y la lectura de `Location` (depende de T011)
- [X] T013 [P] Crear `app/lib/features/diary/undo_snack.dart` (`showUndoSnack(messenger, message, undoLabel, onUndo)`): `SnackBar` de **5 s** (FR-007), con `persist: false` como `undo_delete.dart`, que oculta el aviso anterior. Test `app/test/diary/undo_snack_test.dart`: dura 5 s, «Deshacer» llama a `onUndo` una sola vez y desaparece al pasar el tiempo

**Checkpoint**: T002 en verde; `alembic upgrade head` y `downgrade -1` funcionan; el contrato 0.5.0 es válido; T012 y T013 en verde; `flutter test` verde.

---

## Phase 3: User Story 1 - Añadir desde recientes (Priority: P1) 🎯 MVP

**Goal**: al abrir «añadir» en una comida, el usuario ve sus 30 últimos alimentos distintos con la última cantidad, y añade uno con un toque o ajustando la cantidad.

**Independent Test**: registrar varios alimentos, abrir «añadir» en otra comida y añadir uno de Recientes con un toque (escenarios 1–6 de `quickstart.md`).

### Tests for User Story 1 ⚠️ (escribir primero; deben fallar)

- [X] T014 [P] [US1] `backend/tests/unit/test_quick_suggest.py`: los casos A1–A9 de `contracts/quick-cases.md` sobre `suggest_amount(last, food)`
- [X] T015 [P] [US1] `backend/tests/integration/test_recent_foods.py`:
  - Un alimento registrado 3 veces sale **una** vez, con la cantidad de su último uso
  - 35 alimentos distintos → 30, por `created_at` descendente
  - Una entrada con `deleted_at` no cuenta; si se borra la única de un alimento, deja de ser reciente
  - Un personalizado borrado y un genérico archivado no salen, y los 30 se completan con los siguientes válidos (R1)
  - La lista es global: no depende de la comida
  - `is_favorite` refleja `favorite_food`
  - Un usuario sin entradas recibe `items: []`
- [X] T016 [P] [US1] En `backend/tests/integration/test_diary_entries.py`: `POST /v1/diary/entries` responde `201` con la cabecera `Location: /v1/diary/entries/{id}` donde `{id}` es la entrada creada (R3), y el cuerpo sigue siendo el `DiaryDay` de la 004
- [X] T017 [P] [US1] `backend/tests/contract/test_quick_contract.py`: `GET /v1/foods/recent` valida contra `openapi.yaml` 0.5.0 y **no** responde 422 (orden de routers, R10)
- [X] T018 [P] [US1] Test de widgets `app/test/quick/quick_tabs_test.dart`: con el campo vacío se ven las pestañas Recientes y Favoritos y abre en Recientes; al escribir se ven los resultados y se ocultan las pestañas; vacío de Recientes con «Aquí aparecerán los alimentos que registres, para añadirlos con un toque.»; error de red con «Sin conexión» y «Reintentar»
- [X] T019 [P] [US1] Test de widgets `app/test/quick/quick_food_tile_test.dart`: la fila muestra nombre, marca, cantidad sugerida y kcal; el «+» tiene la etiqueta «Añadir {alimento}, {cantidad}» (p. ej. «Añadir Pan de molde, 2 raciones, 60 g», FR-009); área táctil ≥ 48 × 48 dp; tocar el «+» llama a `addEntry` con `servings` si no es `null` y, si no, con `quantity`; durante el envío no admite otro toque
- [X] T020 [P] [US1] Test de widgets `app/test/quick/quick_add_flow_test.dart`: tras el «+» la pantalla sigue abierta, el día se actualiza con la respuesta y aparece el aviso de 5 s «{alimento} añadido a {comida}» con «Deshacer»; «Deshacer» llama a `deleteEntry` con el id de `Location` y muestra «Deshecho»; si falla, «No se pudo deshacer. Borra la entrada desde el diario.»; tocar el nombre abre la hoja de cantidad con la cantidad sugerida (US1.3)

### Implementation for User Story 1

- [X] T021 [P] [US1] Crear `backend/src/mykcal/quick/suggest.py` (puro, sin E/S; research R2): `suggest_amount(last_servings, last_quantity, last_serving_size, food_serving_size)` → `(quantity, servings)` con las 4 reglas de `data-model.md`. Hace pasar T014
- [X] T022 [US1] Crear `backend/src/mykcal/quick/repository.py` con `recent_entries(session, user_id, limit)`: la última entrada activa de cada `food_id` del usuario (`DISTINCT ON (food_id)` ordenando por `created_at DESC, id DESC`), unida con `food`, descartando personalizados con `deleted_at` y genéricos con `archived_at` (mismas reglas que `create_entry`), ordenada por ese `created_at` descendente y cortada a `limit`. Siempre filtra por `user_id` (principio V). Depende de T004, T005
- [X] T023 [US1] Crear `backend/src/mykcal/quick/service.py` con `list_recent(session, user_id)`: 30 alimentos (FR-001), cantidad sugerida con T021, `is_favorite` consultando `favorite_food`, y el `Food` de la 003 con `is_mine`. Depende de T021, T022
- [X] T024 [US1] En `backend/src/mykcal/quick/router.py` añadir `GET /v1/foods/recent` → `QuickFoodList` (T007). Hace pasar T015 y T017
- [X] T025 [US1] En `backend/src/mykcal/diary/service.py` hacer que `create_entry` devuelva también el id de la entrada creada y en `backend/src/mykcal/diary/router.py` poner `Location: /v1/diary/entries/{id}` en el `201` (R3). No cambia el cuerpo. Hace pasar T016
- [X] T026 [US1] Privacidad de recientes (principio VI, SC-004, FR-008):
  - En `backend/tests/privacy/test_consent_gate.py` añadir `GET /v1/foods/recent` a `HEALTH_DATA_ROUTES`, y comprobar que `test_all_routes_require_identity.py` la cubre
  - Crear `backend/tests/privacy/test_user_isolation_quick.py` con el caso de recientes: el usuario B, con entradas propias, nunca ve en `GET /v1/foods/recent` alimentos que solo registró A (incluidos personalizados de A), e `is_favorite` de B no refleja favoritos de A
- [X] T027 [US1] Registros: en `backend/tests/privacy/test_logs_no_secrets.py` comprobar que listar recientes no deja ningún evento con alimentos ni cantidades (R11)
- [X] T028 [P] [US1] Crear `app/lib/features/quick/recent_foods_controller.dart`: `AsyncNotifier<List<QuickFood>>` de `recentFoods()` (`recentFoodsProvider`), con `refresh()`. En `app/lib/features/diary/diary_day_controller.dart`, `apply(day)` hace `ref.invalidate(recentFoodsProvider)`, de modo que crear, editar, borrar, restaurar, copiar o deshacer refrescan los recientes. Test en `app/test/quick/recent_foods_controller_test.dart`: tras `apply` se vuelve a pedir `recentFoods()`
- [X] T029 [US1] Crear `app/lib/features/quick/quick_food_tile.dart` (T019): fila con nombre y marca, cantidad sugerida y kcal (usar `entry_math.dart`), tocar la fila abre `EntryQuantitySheet` con la cantidad sugerida, y «+» con su etiqueta semántica. El «+» llama a `addEntry`, invalida recientes y llama a la función de aviso de T013
- [X] T030 [US1] Crear `app/lib/features/quick/quick_tabs.dart` (T018): pestañas Recientes y Favoritos con sus estados (cargando, vacío, error con «Reintentar»). En esta historia la pestaña Favoritos muestra solo su estado vacío
- [X] T031 [US1] En `app/lib/features/foods/food_search_screen.dart` mostrar `QuickTabs` mientras el campo de búsqueda esté vacío y en modo selección (`onSelected != null`); al escribir, los resultados de la 003. Fuera del modo selección, sin cambios. En `app/lib/features/diary/entry_quantity_sheet.dart` aceptar una cantidad inicial opcional (g/ml o raciones)
- [X] T032 [US1] Textos nuevos en `app/lib/l10n/app_es.arb` (pestañas, vacíos, etiquetas del «+», avisos y errores) y regenerar `app_localizations`. Sin cadenas en el código (principio VIII)
- [X] T033 [US1] Accesibilidad del «+» y de las pestañas en `app/test/quick/quick_a11y_test.dart` con `app/test/helpers/a11y.dart`: semántica de cada fila y del botón, orden de foco, contraste en claro y oscuro, texto al 200 % sin cortes (FR-009)

**Checkpoint**: US1 funciona sola: Recientes, «+» con un toque, aviso de 5 s con «Deshacer» y hoja de cantidad. Escenarios 1–6 de `quickstart.md`.

---

## Phase 4: User Story 2 - Favoritos (Priority: P2)

**Goal**: el usuario marca alimentos como favoritos desde la búsqueda, recientes y la hoja de una entrada, y los añade con un toque desde su pestaña.

**Independent Test**: marcar y desmarcar favoritos y añadir desde Favoritos (escenarios 7–11 de `quickstart.md`).

### Tests for User Story 2 ⚠️ (escribir primero; deben fallar)

- [X] T034 [P] [US2] `backend/tests/unit/test_quick_ordering.py`: los casos O1–O4 de `contracts/quick-cases.md` sobre `order_favorites(items)` (último uso descendente; los nunca usados al final por `normalize` de la 003)
- [X] T035 [P] [US2] `backend/tests/integration/test_favorites.py`:
  - `PUT` dos veces deja una sola fila y responde `204` las dos
  - `DELETE` de uno que no era favorito responde `204`
  - `PUT` de un personalizado ajeno o borrado, de un genérico archivado y de un id inexistente → `404 FOOD_NOT_FOUND`
  - `GET /v1/foods/favorites` ordena por último uso y los nunca usados al final por nombre (FR-010)
  - Un favorito cuyo personalizado se borra deja de listarse
  - La cantidad sugerida de un favorito sin uso es 1 ración si el alimento la tiene y 100 g/ml si no (FR-004)
  - Eventos `favorite_added` y `favorite_removed` con `user_id` y sin nombre de alimento
- [X] T036 [P] [US2] En `backend/tests/contract/test_quick_contract.py` añadir `GET /v1/foods/favorites`, `PUT` y `DELETE /v1/foods/favorites/{food_id}` contra el contrato (depende de T017)
- [X] T037 [P] [US2] Test `app/test/quick/favorites_controller_test.dart`: `toggle` marca de forma optimista y revierte con aviso si la petición falla; `favoriteIdsProvider` refleja el conjunto; `FOOD_NOT_FOUND` muestra «Este alimento ya no está disponible» y deja la estrella como estaba
- [X] T038 [P] [US2] Test de widgets `app/test/quick/favorite_star_test.dart`: etiqueta «Marcar {alimento} como favorito» o «Quitar {alimento} de favoritos» según el estado (nunca empieza por «Añadir», para no confundirse con el «+»), área táctil ≥ 48 × 48 dp; en la pestaña Favoritos, desmarcar quita la fila y muestra el aviso de 5 s «Quitado de favoritos» con «Deshacer»; estrella visible en resultados de búsqueda, recientes y hoja de una entrada (FR-003); vacío «Marca alimentos con ☆ para tenerlos a mano aquí.»

### Implementation for User Story 2

- [X] T039 [P] [US2] Crear `backend/src/mykcal/quick/ordering.py` (puro; research R8): `order_favorites(items)` por `last_used_at` descendente y, al final, los nunca usados por nombre normalizado, con desempate estable por nombre. Hace pasar T034
- [X] T040 [US2] En `backend/src/mykcal/quick/repository.py` añadir `add_favorite` (`INSERT … ON CONFLICT DO NOTHING`), `remove_favorite` (borrado físico) y `favorites_with_last_use(session, user_id)` (favoritos unidos con `food` disponible y con su última entrada activa si la hay). Siempre filtran por `user_id`. Depende de T004
- [X] T041 [US2] En `backend/src/mykcal/quick/service.py` añadir `list_favorites` (usa T039 y T021 para la cantidad sugerida), `mark_favorite` (valida con `foods_repository.get_visible` y genérico no archivado; si no, `food_not_found()` de la 003) y `unmark_favorite`. Registran `favorite_added` y `favorite_removed` con `user_id` y duración, sin alimento (R11)
- [X] T042 [US2] En `backend/src/mykcal/quick/router.py` añadir `GET /v1/foods/favorites`, `PUT /v1/foods/favorites/{food_id}` y `DELETE /v1/foods/favorites/{food_id}` (`204`). Hace pasar T035 y T036
- [X] T043 [US2] Privacidad de favoritos: en `backend/tests/privacy/test_consent_gate.py` añadir las 3 rutas de favoritos a `HEALTH_DATA_ROUTES`; en `backend/tests/privacy/test_logs_no_secrets.py` comprobar que `favorite_added` y `favorite_removed` no llevan alimento ni cantidad; en `backend/tests/privacy/test_user_isolation_quick.py` (T026) añadir: B no ve los favoritos de A en `GET /v1/foods/favorites`, `PUT /v1/foods/favorites/{id}` de un personalizado de A → `404 FOOD_NOT_FOUND` con cuerpo idéntico al de un id inexistente, y el `DELETE` de B no quita el favorito de A
- [X] T044 [P] [US2] Crear `app/lib/features/quick/favorites_controller.dart`: `AsyncNotifier<List<QuickFood>>` de `favoriteFoods()` con `toggle(Food)` optimista, y `favoriteIdsProvider` (`Set<String>`) derivado (R9). Se carga una vez por sesión. Hace pasar T037
- [X] T045 [P] [US2] Crear `app/lib/features/quick/favorite_star.dart`: estrella reutilizable con su semántica y su área táctil de 48 dp. Hace pasar T038
- [X] T046 [US2] Poner la estrella en `app/lib/features/quick/quick_food_tile.dart`, en las filas de resultados de `app/lib/features/foods/food_search_screen.dart` y en la cabecera de `app/lib/features/diary/entry_quantity_sheet.dart` en modo editar. En `quick_tabs.dart` completar la pestaña Favoritos (lista, vacío y desmarcar con aviso de 5 s)
- [X] T047 [US2] Textos de favoritos en `app/lib/l10n/app_es.arb` y regenerar `app_localizations`
- [X] T048 [US2] Ampliar `app/test/quick/quick_a11y_test.dart` (T033) a la estrella y a la pestaña Favoritos

**Checkpoint**: US2 funciona: favoritos desde las tres pantallas, pestaña ordenada y «+» con un toque. Escenarios 7–11. US1 sigue verde.

---

## Phase 5: User Story 3 - Copiar una comida de otro día (Priority: P2)

**Goal**: el usuario duplica una comida de los 14 días anteriores en cualquier comida del día visible, añadiendo a lo que ya hay, y puede deshacerlo durante 5 s.

**Independent Test**: copiar el desayuno de ayer al de hoy y comprobar que ayer no cambia (escenarios 12–18 de `quickstart.md`).

### Tests for User Story 3 ⚠️ (escribir primero; deben fallar)

- [X] T049 [P] [US3] `backend/tests/unit/test_copy_rules.py`: los casos C1–C4 (orden de comidas con el tipo del destino primero, días vacíos fuera, ventana 2026-11-10 … 2026-11-23 para destino 2026-11-24) y V1–V5 (valores de la copia) de `contracts/quick-cases.md`
- [X] T050 [P] [US3] `backend/tests/integration/test_diary_copy.py`:
  - Copiar a una comida vacía y a una con entradas: se **suman** sin borrar nada (US3.3)
  - La comida origen queda idéntica fila a fila (SC-003)
  - Se puede copiar a otra comida distinta (US3.4)
  - Las copias tienen el mismo `copy_id`, `created_at` actual y `entry_date` y `meal` del destino
  - `source_date` igual o posterior al destino, o anterior a `target_date − 14` → `400 DIARY_DATE_OUT_OF_RANGE`; `target_date` fuera de alta ≤ fecha ≤ hoy → `400 DIARY_DATE_OUT_OF_RANGE`
  - Origen sin entradas activas → `400 COPY_SOURCE_EMPTY`
  - Valores V1–V5: actuales si el alimento está disponible, los de la entrada si no (FR-006)
  - Deshacer con el reloj inyectado: a los 60 s borra solo las copiadas aunque haya otras entradas añadidas después; a los 61 s, una segunda vez, o con un `copy_id` ajeno → `404 COPY_NOT_FOUND`
  - Cada operación devuelve el día destino completo
  - `GET /v1/diary/copy-sources`: solo los 14 días anteriores con entradas, el más reciente primero; las comidas del mismo tipo que el destino primero; `values_changed` correcto; kcal por la copia de la entrada
- [X] T051 [P] [US3] En `backend/tests/contract/test_quick_contract.py` añadir `GET /v1/diary/copy-sources`, `POST /v1/diary/copies` y `DELETE /v1/diary/copies/{copy_id}` contra el contrato 0.5.0
- [X] T052 [P] [US3] Test de widgets `app/test/diary/copy_meal_sheet_test.dart`:
  - Lista por días con «Ayer» para el anterior, comida del mismo tipo primero, hasta 3 entradas y «+N más» desplegable, total de kcal por comida
  - Selección única; «Copiar» desactivado hasta elegir
  - Línea «Algún alimento ha cambiado: se copiará con sus valores actuales.» cuando `valuesChanged`
  - Vacío «No hay comidas en los 14 días anteriores.»
  - Sin conexión: la hoja sigue abierta con la selección, con «Sin conexión» y «Reintentar»
  - Tras copiar: cierra la hoja, actualiza el día y muestra el aviso de 5 s «{n} alimentos copiados a {comida}» con «Deshacer», que llama a `undoCopy` y muestra «Copia deshecha»
  - Semántica: cada opción se lee entera (comida, día, kcal, nº de alimentos y nombres con cantidad)

### Implementation for User Story 3

- [X] T053 [P] [US3] Crear `backend/src/mykcal/diary/copy_rules.py` (puro; research R6, R7): `copy_window(target_date)` → `[target_date − 14, target_date − 1]`; `order_meals(meals, target_meal)` con la del destino primero y el resto en el orden fijo; `copied_values(source_entry, food)` con la tabla de valores de `data-model.md` (`food_id` y `food_kind` siempre de la origen; raciones solo si `serving_size` no cambió). Hace pasar T049
- [X] T054 [P] [US3] En `backend/src/mykcal/diary/schemas.py` añadir `DiaryCopyCreate` (`extra="forbid"`; `source_date`, `source_meal`, `target_date`, `target_meal`), `DiaryCopyResult` (`copy_id`, `entry_ids` con al menos 1, `day`), `CopySourceEntry`, `CopySourceMeal` (`entries` con al menos 1, `kcal`, `values_changed`), `CopySourceDay` (`meals` de 1 a 5) y `CopySourceList` (`days` hasta 14), según `contracts/api-changes.md`
- [X] T055 [US3] En `backend/src/mykcal/diary/repository.py` añadir `entries_of_meal(session, user_id, day, meal)`, `entries_in_range(session, user_id, first, last)` y `entries_of_copy(session, user_id, copy_id)` (solo activas), siempre con `user_id`. Depende de T005
- [X] T056 [US3] En `backend/src/mykcal/diary/service.py` añadir:
  - `copy_sources(session, user_id, registered_at, target_date, target_meal, now)`: valida `target_date` con `validate_entry_date`, lee el rango de T055 y arma los días con T053
  - `copy_meal(...)`: en **una transacción** valida destino y ventana, exige origen no vacío (`COPY_SOURCE_EMPTY`), crea una entrada nueva por cada una con `copy_id` común, mismo orden y `get_visible` para los valores (T053), y devuelve `DiaryCopyResult` con `get_day`. Registra `diary_meal_copied` con `user_id`, comidas, `entries_count` y duración, sin fechas ni alimentos (R11)
  - `undo_copy(...)`: borra lógicamente las entradas activas con ese `copy_id` si la copia tiene ≤ `RESTORE_WINDOW` (60 s) y devuelve el día; si no, `COPY_NOT_FOUND`. Registra `diary_copy_undone`
  - Depende de T006, T053, T054, T055
- [X] T057 [US3] En `backend/src/mykcal/diary/router.py` añadir `GET /v1/diary/copy-sources` (sin `utc_offset_min`), `POST /v1/diary/copies` (`201`) y `DELETE /v1/diary/copies/{copy_id}` (`200 DiaryDay`), las dos últimas con `utc_offset_min`. Hace pasar T050 y T051
- [X] T058 [US3] Privacidad de la copia: en `backend/tests/privacy/test_consent_gate.py` añadir las 3 rutas de copia a `HEALTH_DATA_ROUTES`; en `backend/tests/privacy/test_logs_no_secrets.py` comprobar que `diary_meal_copied` y `diary_copy_undone` no llevan alimento, cantidad ni fecha; en `backend/tests/privacy/test_user_isolation_quick.py` (T026) añadir: `copy-sources` de B nunca incluye comidas de A; `POST /v1/diary/copies` de B con la fecha y comida de una comida de A (y ninguna propia) → `400 COPY_SOURCE_EMPTY`, sin crear nada; `DELETE /v1/diary/copies/{copy_id}` de B con un `copy_id` de A → `404 COPY_NOT_FOUND`, con cuerpo idéntico al de un id inexistente, y las entradas de A siguen activas
- [X] T059 [P] [US3] Crear `app/lib/features/diary/copy_sources_provider.dart`: `FutureProvider.autoDispose.family` de `copySources(fecha, comida)` (R12)
- [X] T060 [US3] Crear `app/lib/features/diary/copy_meal_sheet.dart` según `contracts/ui-flows.md` §3: lista de T052, selección única, «Copiar» con `copyMeal`, aplicar `result.day` a `diary_day_controller.dart`, invalidar recientes (T028) y mostrar el aviso de 5 s (T013) con «Deshacer» → `undoCopy`. Errores con «Reintentar» conservando la selección. Hace pasar T052
- [X] T061 [US3] En `app/lib/features/diary/meal_section.dart` añadir el menú ⋮ de la cabecera con «Copiar de otro día», que abre la hoja con la fecha visible y esa comida como destino
- [X] T062 [US3] Textos de la hoja de copiar en `app/lib/l10n/app_es.arb` y regenerar `app_localizations`
- [X] T063 [US3] Accesibilidad de la hoja y del menú en `app/test/diary/copy_a11y_test.dart`: lectura completa de cada opción, foco, contraste en claro y oscuro, texto al 200 % sin cortes (FR-009)

**Checkpoint**: US3 funciona: copiar, sumar al destino, deshacer solo lo copiado. Escenarios 12–18. US1 y US2 siguen verdes.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T064 [P] Revisar `backend/tests/privacy/test_user_isolation_quick.py` (creado en T026 y ampliado en T043 y T058; SC-004, FR-008): que cubre las 7 rutas nuevas con un caso cada una y que todo `404` ajeno tiene el mismo cuerpo que «no existe». Añadir lo que falte de las historias entregadas
- [X] T065 [P] `backend/tests/privacy/test_all_routes_require_identity.py`: comprobar que las 7 rutas nuevas rechazan una petición sin identidad y que `PUBLIC_ROUTES` no cambia
- [X] T066 Revisar que `flutter analyze` y `ruff check` no dejan avisos, que no hay cadenas fuera del ARB y que no se añadió ninguna dependencia (R14)
- [ ] T067 Ejecutar el `quickstart.md` §1–§3: pruebas automáticas en verde, `alembic upgrade head` → `downgrade -1` → `upgrade head`, y los 21 escenarios de §4 contra el backend local en el móvil o emulador, incluidos TalkBack y texto al 200 % (escenario 21). Anotar en el PR los tiempos medidos: escenario 3 (< 5 s desde Inicio, SC-001), escenario 13 (< 15 s, SC-002) y la duración en el servidor de `GET /v1/foods/recent` y `GET /v1/foods/favorites` en los registros de uvicorn (< 100 ms, plan)
- [ ] T068 Tras fusionar y desplegar desde `main` (principio IX, `quickstart.md` §5): repetir en producción los escenarios 3, 8, 13 y 16 y marcar la feature como cerrada

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias
- **Foundational (Phase 2)**: depende de Setup; **bloquea** todas las historias
- **US1, US2, US3 (Phases 3–5)**: dependen solo de Foundational
  - US2 reutiliza `quick_food_tile.dart`, `quick_tabs.dart` y `quick/service.py` de US1 (T029, T030, T023); si se hace US2 antes, esas piezas se crean allí y US1 las completa
  - US3 es independiente de US1 y US2 en backend y en app, salvo T028 (invalidar recientes tras copiar), que se omite si US1 no está
- **Polish (Phase 6)**: depende de las historias deseadas

### Within Each Story

- Tests antes que implementación, y deben fallar
- Funciones puras (`suggest`, `ordering`, `copy_rules`) → repositorio → servicio → ruta → privacidad
- Backend y contrato antes de la app de esa historia

### Parallel Opportunities

- Phase 2: T002, T004, T005, T007, T011 y T013 en paralelo; T010 tras T004 y T005; T009 puede ir en paralelo con ellas (solo toca `openapi.yaml`)
- US1: T014–T020 en paralelo; T021 y T028 en paralelo
- US2: T034–T038 en paralelo; T039, T044 y T045 en paralelo
- US3: T049–T052 en paralelo; T053, T054 y T059 en paralelo
- Con varias personas: tras Phase 2, una en US1, otra en US3 y la tercera en US2 tras T029–T030

## Parallel Example: User Story 1

```text
Task: "test_quick_suggest.py (A1–A9)"                          # T014
Task: "test_recent_foods.py"                                    # T015
Task: "Location en POST /v1/diary/entries"                      # T016
Task: "quick_food_tile_test.dart y quick_tabs_test.dart"        # T018, T019
Task: "suggest.py"                                              # T021
Task: "recent_foods_controller.dart"                            # T028
```

## Implementation Strategy

### MVP First (solo User Story 1)

1. Phase 1 y Phase 2
2. Phase 3: Recientes y «+» con deshacer
3. **Parar y validar**: escenarios 1–6; es la mayor ganancia de tiempo (spec, US1)
4. Fusionar a `dev` si el plazo aprieta (las épicas P2 son las primeras en recortarse)

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → probar → demo (MVP)
3. US2 → probar → demo
4. US3 → probar → demo
5. Polish y cierre en producción (T064–T068)

## Notes

- [P] = archivos distintos, sin dependencias pendientes
- La etiqueta [Story] enlaza cada tarea con su historia
- Sin dependencias nuevas (R14); no se abre ninguna ruta pública
- Las kcal y valores salen siempre de la base de alimentos o de la entrada ya copiada de ella (principio II)
- Commit tras cada tarea o grupo lógico
