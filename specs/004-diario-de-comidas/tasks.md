# Tasks: Diario de comidas y resumen diario

**Input**: Design documents from `specs/004-diario-de-comidas/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R16), data-model.md, contracts/ (`api-changes.md`, `summary-cases.md`, `ui-flows.md`), quickstart.md

**Tests**: se incluyen. Se sigue la práctica de la 001–003 (test primero) y el principio VI. Los tests de cada historia se escriben antes y deben fallar.

**Organization**: por historia de usuario. Lo común (migración, modelo, errores, esquemas, contrato y base de la app) está en la Phase 2. Las historias comparten el recurso «entrada», pero cada una añade una ruta y una pantalla propias.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de `spec.md` (US1 ver el resumen, US2 añadir, US3 editar y borrar, US4 días pasados)
- Rutas de backend relativas a `backend/src/mykcal/` salvo que se indique `backend/tests/` o `backend/alembic/`; las de la app, a `app/`.

---

## Phase 1: Setup

- [X] T001 Comprobar que la rama es `004-diario-de-comidas` y que `cd backend && uv run pytest` y `cd app && flutter test` pasan antes de empezar (línea base de la 003)

---

## Phase 2: Foundational (bloquea todas las historias)

### Base de datos y modelo (R4, R5)

- [X] T002 [P] Añadir a `backend/tests/integration/test_migrate.py` los casos de `0004_diary` (suben y bajan, y los CHECK de `data-model.md`): `meal = 'brunch'` → error; `quantity = 0` → error; `quantity = 10000.1` → error; `servings = 0` → error; `servings = 100.5` → error; `servings` con `serving_size NULL` → error; `base_unit = 'kg'` → error; dos entradas con el mismo usuario, día, comida y alimento → **permitido** (clarificación 1)
- [X] T003 Crear `backend/alembic/versions/0004_diary.py` (`revision = "0004_diary"`, `down_revision = "0003_foods"`, con `downgrade`) con la tabla `diary_entry` de `data-model.md`, constraints verbatim:
  - Columnas: `id uuid PK default gen_random_uuid()`, `user_id uuid NOT NULL FK user_account.id`, `entry_date date NOT NULL`, `meal text NOT NULL`, `food_id uuid NOT NULL FK food.id`, `food_kind text NOT NULL`, `food_name text NOT NULL`, `food_brand text NULL`, `base_unit text NOT NULL`, `serving_size numeric(7,2) NULL`, `kcal`, `protein_g`, `carbs_g`, `fat_g` `numeric(8,2) NOT NULL` (copia por 100), `fiber_g`, `sodium_mg`, `potassium_mg`, `calcium_mg`, `iron_mg`, `magnesium_mg`, `vitamin_d_ug`, `vitamin_c_mg` `numeric(8,2) NULL` (`NULL` = sin dato), `quantity numeric(7,1) NOT NULL`, `servings numeric(5,2) NULL`, `created_at` y `updated_at` `timestamptz NOT NULL`, `deleted_at timestamptz NULL`
  - CHECK `ck_diary_meal`: `meal IN ('breakfast','lunch','afternoon_snack','dinner','snacks')`; `ck_diary_unit`: `base_unit IN ('g','ml')`; `ck_diary_quantity`: `quantity > 0 AND quantity <= 10000`; `ck_diary_servings`: `servings IS NULL OR (servings > 0 AND servings <= 100)`; `ck_diary_servings_size`: `servings IS NULL OR serving_size IS NOT NULL`; `ck_diary_nutrients`: los 12 valores `>= 0` cuando no son `NULL`
  - Índice `ix_diary_entry_user_date (user_id, entry_date) WHERE deleted_at IS NULL`. **Sin** unicidad por alimento y comida (R7)
  - Hace pasar T002
- [X] T004 [P] Crear `backend/src/mykcal/diary/__init__.py` y `backend/src/mykcal/diary/models.py` con `DiaryEntry` (SQLAlchemy 2, mismo estilo que `foods/models.py`) según T003, y registrarlo donde `backend/alembic/env.py` y `backend/tests/conftest.py` cargan el metadata
- [X] T005 En `backend/src/mykcal/core/errors.py` añadir a `ErrorCode`: `DIARY_DATE_OUT_OF_RANGE` y `ENTRY_NOT_FOUND` (R11, `contracts/api-changes.md`)

### Esquemas, router y contrato

- [X] T006 [P] Crear `backend/src/mykcal/diary/schemas.py` con `Meal` (`breakfast`, `lunch`, `afternoon_snack`, `dinner`, `snacks`), `DiaryEntryCreate` (`extra="forbid"`; `date`, `meal`, `food_id`, y exactamente uno de `quantity` —`gt=0`, `le=10000`, 1 decimal— o `servings` —`gt=0`, `le=100`, 2 decimales—), `DiaryEntryUpdate` (`extra="forbid"`, al menos un campo, nunca `quantity` y `servings` juntos), `DiaryEntry` (con `per_100: Nutrients` y `values: Nutrients` reutilizando `foods.schemas.Nutrients`, y `incomplete`), `NutrientTotals`, `DiaryMeal` y `DiaryDay`, con los campos y tipos de `contracts/api-changes.md`
- [X] T007 Crear `backend/src/mykcal/diary/router.py` con `APIRouter(prefix="/v1/diary")` cuyas rutas dependen de `require_consent` (R11) y, en `backend/src/mykcal/main.py`, incluirlo. Las rutas las añaden las historias. Todas reciben `utc_offset_min: int = Query(ge=-840, le=840)` obligatorio
- [X] T008 Actualizar `specs/001-acceso-y-despliegue/contracts/openapi.yaml` con el «Fragmento OpenAPI» de `specs/004-diario-de-comidas/contracts/api-changes.md` (5 rutas, parámetros `DiaryDate`, `EntryId` y `UtcOffsetMin`, respuestas `DiaryDayOk`, `DiaryBadRequest`, `EntryNotFound` y `TargetNotFound`, schemas nuevos, `DIARY_DATE_OUT_OF_RANGE` y `ENTRY_NOT_FOUND` en el enum de `ErrorBody.code`, `Me.registered_at` en `required`, `info.version: 0.4.0`)
- [X] T009 [P] En `backend/tests/conftest.py` añadir los helpers: `make_entry(user, day, meal, food=None, quantity=..., servings=None, deleted_at=None)` que inserta una `DiaryEntry` copiando el alimento (reutiliza `make_food`), y `make_target_version(user, effective_from, kcal=2000, ...)` que inserta una versión de `daily_target` con los 12 valores. Los usan los tests de todas las historias

### `Me.registered_at` (R2)

- [X] T010 [P] Test en `backend/tests/contract/test_me_contract.py`: `GET /v1/me` devuelve `registered_at` igual a `user_account.created_at` y valida contra el contrato
- [X] T011 Añadir `registered_at: datetime` a `Me` en `backend/src/mykcal/accounts/schemas.py` y rellenarlo en `_me()` de `backend/src/mykcal/accounts/router.py` con `account.created_at`. Hace pasar T010

### Base de la app

- [X] T012 [P] En `app/lib/core/api/models.dart` añadir: `Me.registeredAt` (`DateTime`, de `registered_at`; actualizar los constructores de prueba), `Meal` (enum con `breakfast`…`snacks` y `parse`/`wire`), `DiaryEntry` (con `per100: Nutrients`, `values: Nutrients`, `incomplete`, `servings`, `servingSize`, `quantity`), `NutrientTotals`, `DiaryMeal` y `DiaryDay` (con `target: TargetValues`, `remaining: Map<String, double>`) con `fromJson` según `contracts/api-changes.md`; `null` en un nutriente se conserva como «sin dato»
- [X] T013 En `app/lib/core/api/mykcal_api.dart` añadir a `MykcalApi` y a `HttpMykcalApi`: `diaryDay(DateTime date, int utcOffsetMin)`, `addEntry(...)`, `updateEntry(...)`, `deleteEntry(String id, DateTime date, int utcOffsetMin)` y `restoreEntry(...)`, cada una devolviendo `DiaryDay` y enviando `utc_offset_min` en el *query string*. Actualizar los fakes de `app/test/helpers/fakes.dart`. Test de cliente en `app/test/api/diary_api_test.dart` para el mapeo de `DIARY_DATE_OUT_OF_RANGE`, `ENTRY_NOT_FOUND`, `FOOD_NOT_FOUND` y `VALIDATION_ERROR` con `fields` (depende de T012)
- [X] T014 [P] Test puro `app/test/diary/local_day_test.dart` y crear `app/lib/features/diary/local_day.dart` (R1, R3): `LocalDay.today(now)` y `dateOnly(DateTime)` devuelven la fecha local sin hora; `isoDate()` da `AAAA-MM-DD`; `utcOffsetMin(DateTime day)` devuelve el desfase de la zona **al final de ese día** (`DateTime(y, m, d + 1).timeZoneOffset.inMinutes`), con casos en el cambio de hora (un día de 23 y otro de 25 horas); `sameDay(a, b)`; `isBefore`/`isAfter` por fecha
- [X] T015 [P] Test puro `app/test/diary/entry_math_test.dart` y crear `app/lib/features/diary/entry_math.dart` (R13): `valuesFor(Nutrients per100, double quantity)` con `por_100 × quantity / 100` y el mismo redondeo que el servidor (kcal y micros a entero; proteína, carbohidratos, grasa y fibra a 1 decimal; `ROUND_HALF_UP`); `quantityFromServings(servings, servingSize)` redondeada a 1 decimal; los `null` se conservan. Casos de `contracts/summary-cases.md` S2, S3, S8 y Q1

**Checkpoint**: T002 y T010 en verde; `alembic upgrade head` y `downgrade -1` funcionan; T014 y T015 en verde; `flutter test` verde.

---

## Phase 3: User Story 1 — Ver el resumen del día (P1) 🎯 MVP

**Goal**: al abrir la app, Inicio muestra el resumen del día (consumido, objetivo y restante de calorías y macros; fibra y micros en el detalle) y las cinco comidas con lo registrado.

**Independent Test**: con un objetivo y algunas entradas insertadas por la base, abrir la app y comprobar que consumido + restante = objetivo para cada valor (SC-002), que el exceso se ve con texto e icono, y que los micros con datos faltantes dicen «incompleto».

### Tests (escribir primero)

- [X] T016 [P] [US1] Test unitario `backend/tests/unit/test_diary_summary.py` con los casos S1–S10 y M1–M3 de `contracts/summary-cases.md`: valores de entrada con `Decimal` desde la copia por 100, totales con `sum_nutrients`, `ROUND_HALF_UP` (kcal y micros a entero; proteína, carbohidratos, grasa y fibra a 1 decimal), redondeo del total y no de cada entrada, `restante = objetivo − consumido redondeado` con negativos (exceso), `incomplete` en el total del día **y** en cada comida, las 5 comidas siempre en el orden `breakfast, lunch, afternoon_snack, dinner, snacks`, y en todos los casos `consumido + restante = objetivo`
- [X] T017 [P] [US1] Test unitario `backend/tests/unit/test_day_end.py` con T1–T6 de `contracts/summary-cases.md`: `day_end_utc(day, utc_offset_min) = (day + 1) a las 00:00 UTC − offset` y selección del objetivo con `effective_from < fin_del_día` más reciente; si no hay ninguno, la versión más antigua
- [X] T018 [P] [US1] Test de integración `backend/tests/integration/test_diary_day.py` (FR-006–FR-009, FR-011): `GET /v1/diary/days/{date}` sin entradas → consumido 0 y restante = objetivo (US1.1); con entradas en distintas comidas, los totales por comida y del día cuadran (US1.2); una entrada borrada (`deleted_at`) no se devuelve ni suma; con dos versiones de `daily_target`, un día pasado usa la antigua y hoy la nueva (US4.3); sin ninguna versión → `404 TARGET_NOT_FOUND`; `utc_offset_min` fuera de −840..840 → `400 VALIDATION_ERROR`; sin `utc_offset_min` → `400`
- [X] T019 [P] [US1] Test de contrato `backend/tests/contract/test_diary_contract.py`: la respuesta de `GET /v1/diary/days/{date}` valida contra `openapi.yaml` 0.4.0 (`DiaryDay`, 5 comidas, `remaining` con los 12 nutrientes)
- [X] T020 [P] [US1] Test de widgets `app/test/diary/summary_card_test.dart` (FR-006, FR-014, R14): muestra consumido, objetivo y restante de kcal, proteína, carbohidratos y grasa; con exceso muestra «+150 kcal», un icono `warning_amber` y color de error y **no** solo color (comprobar texto e icono); la semántica de cada fila es una sola frase («Calorías: 2.150 de 2.000, 150 por encima»); las barras son `ExcludeSemantics`; con un macro en `incomplete` aparece «incompleto» con icono. Usa `app/test/helpers/a11y.dart`
- [X] T021 [P] [US1] Test de widgets `app/test/diary/summary_detail_sheet_test.dart` (FR-007, US1.4): fibra y los 7 micros con consumido y objetivo («Fibra 18,0 / 25 g»); sodio como máximo («Sodio 1.900 mg · máx. 2.300 · quedan 400» y «300 por encima del límite»); los nutrientes en `incomplete` llevan «incompleto» y su explicación
- [X] T022 [P] [US1] Test de widgets `app/test/diary/diary_screen_test.dart` (US1.1, US1.2, FR-001, FR-009, FR-012): con un `DiaryDay` simulado se ven las 5 comidas en orden con su total de kcal; cada entrada muestra nombre, marca, cantidad («60 g», «2 raciones · 60 g») y kcal; la comida vacía dice «Aún no hay nada»; carga y error con `ConnectionErrorView` y «Reintentar»; «Ver objetivo» abre la pantalla del objetivo

### Implementación — backend

- [X] T023 [US1] Crear `backend/src/mykcal/diary/day.py` (R1, R3), puro: `day_end_utc(day: date, utc_offset_min: int) -> datetime` y `pick_target(versions, day_end)` que elige la versión con `effective_from < day_end` más reciente o, si no hay, la más antigua. Hace pasar T017
- [X] T024 [US1] Crear `backend/src/mykcal/diary/summary.py` (R10), puro: `entry_values(entry) -> dict[str, Decimal | None]`, `build_day(target, entries) -> DiaryDay` con `sum_nutrients` de `foods/nutrients.py`, redondeo `ROUND_HALF_UP`, `remaining` y las 5 comidas en orden fijo. Hace pasar T016
- [X] T025 [US1] En `backend/src/mykcal/targets/service.py` añadir `target_for_day(session, user_id, day_end_utc) -> DailyTarget | None` que usa el índice `ix_daily_target_user_effective` y `pick_target` (R3). Sin versiones, devuelve `None`
- [X] T026 [US1] Crear `backend/src/mykcal/diary/repository.py` con `entries_of_day(session, user_id, day)` (`deleted_at IS NULL`, orden de `created_at`; siempre con `user_id`) y `backend/src/mykcal/diary/service.py` con `get_day(session, user_id, day, utc_offset_min)` que arma el `DiaryDay` y lanza `ApiError(404, TARGET_NOT_FOUND)` si no hay objetivo
- [X] T027 [US1] Añadir a `backend/src/mykcal/diary/router.py` `GET /v1/diary/days/{date}` (`response_model=DiaryDay`). Hace pasar T018 y T019

### Implementación — app

- [X] T028 [P] [US1] Añadir a `app/lib/l10n/app_es.arb` los textos del diario: nombres de las 5 comidas, «Hoy», «Aún no hay nada», «Calorías», «Proteína», «Carbohidratos», «Grasa», «Quedan {n}», «+{n} {unidad} por encima», «incompleto» y su explicación, «Ver detalle», «Ver objetivo», «Este día usó el objetivo que tenías entonces», «Añadido a {comida}», y las frases semánticas del resumen. Regenerar `app_localizations*.dart`
- [X] T029 [US1] Crear `app/lib/features/diary/diary_day_controller.dart` (R13): `AsyncNotifier.family<DiaryDay, DateTime>` que pide `diaryDay(date, LocalDay.utcOffsetMin(date))`, expone `apply(DiaryDay)` para sustituir el estado con la respuesta de cualquier ruta, y `refresh()`. Provider con `mykcalApiProvider`
- [X] T030 [P] [US1] Crear `app/lib/features/diary/summary_card.dart` según `contracts/ui-flows.md` §1 (R14). Hace pasar T020
- [X] T031 [P] [US1] Crear `app/lib/features/diary/summary_detail_sheet.dart` con fibra y los 7 micros. Hace pasar T021
- [X] T032 [P] [US1] Crear `app/lib/features/diary/meal_section.dart`: cabecera con el nombre de la comida y su total de kcal, lista de entradas (nombre, marca, cantidad, kcal) y botón «+» con área ≥ 48 dp y etiqueta «Añadir a {comida}». Callbacks `onAdd` y `onTapEntry`, que las historias US2 y US3 conectan
- [X] T033 [US1] Crear `app/lib/features/diary/diary_screen.dart` (FR-012): resumen, «Ver detalle» y «Ver objetivo» (abre `TargetScreen`), y las 5 `MealSection`. De momento muestra siempre hoy (la navegación es de US4). Hace pasar T022
- [X] T034 [US1] Cambiar `app/lib/features/home/home_screen.dart`: el cuerpo pasa a ser `DiaryScreen` (sin saludo, sin `TargetCard` ni botón «Alimentos») y el menú ⋮ añade «Alimentos» que abre `FoodSearchScreen` en modo consulta. Actualizar `app/test/home/` y `app/test/app_gate_test.dart` para el cuerpo nuevo

**Checkpoint**: US1 funciona de principio a fin con entradas insertadas por la base. Backend: T016–T019 en verde. App: el diario se ve en el emulador con el backend local.

---

## Phase 4: User Story 2 — Añadir un alimento a una comida (P1)

**Goal**: desde una comida, buscar o escanear un alimento, indicar la cantidad (g, ml o raciones) y añadirlo. El resumen se actualiza al momento.

**Independent Test**: añadir un genérico en gramos y un envasado por raciones, y comprobar que los valores son los de la base por la cantidad y que el resumen cambia (SC-001, SC-003).

### Tests (escribir primero)

- [X] T035 [P] [US2] Test unitario `backend/tests/unit/test_diary_quantity.py` con Q1–Q7 de `contracts/summary-cases.md` (R6): `servings × serving_size` redondeado a 1 decimal con `ROUND_HALF_UP` (Q1); `servings` sin `serving_size` → error con `fields=["servings"]` (Q2); `quantity` y `servings` a la vez o ninguno → error (Q3, Q4); 0, negativo y > 10.000 → error (Q4, Q5)
- [X] T036 [P] [US2] Test de integración `backend/tests/integration/test_diary_entries.py` (FR-002–FR-004): `POST /v1/diary/entries` con 150 g de un alimento de 200 kcal/100 g crea una entrada de 300 kcal y devuelve el día con `201` (US2.1); con 2 raciones de un envasado de 30 g guarda `quantity = 60,0` y `servings = 2` (US2.2); copia nombre, marca, `base_unit`, `serving_size` y los 12 nutrientes por 100 **tal como están en el alimento**, incluidos los `NULL`; añadir el mismo alimento dos veces a la misma comida crea dos entradas (clarificación 1, S9); `quantity: 0`, `-5`, vacío, `servings` sin ración y los dos campos a la vez → `400 VALIDATION_ERROR` con `fields`; alimento inexistente, personalizado ajeno o borrado, o genérico archivado → `404 FOOD_NOT_FOUND`; no se puede enviar ningún valor nutricional (campo desconocido → `400`)
- [X] T037 [P] [US2] Test de integración `backend/tests/integration/test_diary_snapshot.py` (FR-004, SC-004): tras registrar un personalizado, editarlo (nombre y valores) y eliminarlo, la entrada del diario conserva el nombre y los valores originales y el día los suma igual
- [X] T038 [P] [US2] Test de widgets `app/test/diary/entry_quantity_sheet_test.dart` — modo añadir (US2.1–US2.4, R13): la unidad por defecto es «raciones» (1) si el alimento tiene ración y g/ml con foco en el campo si no; la vista previa cambia al escribir (US2.3) y coincide con `entry_math`; vacío, 0 o negativo → «Indica una cantidad mayor que 0» y «Añadir» desactivado; más de 10.000 → «Máximo 10.000»; más de 5.000 g/ml → diálogo «¿Seguro? Son 6.000 g» con «Cambiar» y «Sí, añadir»; con la red caída la hoja **sigue abierta con lo escrito** y muestra «Sin conexión» con «Reintentar» (edge case)
- [X] T039 [P] [US2] Test de widgets `app/test/diary/add_flow_test.dart`: «+» en Desayuno abre `FoodSearchScreen` en modo selección con título «Añadir a Desayuno»; elegir un resultado abre la hoja; «Añadir» cierra hoja y búsqueda, vuelve al diario con el día de la respuesta y muestra «Añadido a Desayuno»; el resultado «encontrado» del escáner devuelve el alimento en modo selección

### Implementación — backend

- [X] T040 [US2] Crear `backend/src/mykcal/diary/quantity.py` (R6), puro: `resolve_quantity(quantity, servings, serving_size) -> (Decimal, Decimal | None)` con los límites y errores de T035. Hace pasar T035
- [X] T041 [US2] Añadir a `backend/src/mykcal/diary/repository.py` `add_entry(session, user_id, ...)`, y la lectura de un alimento **visible para el usuario** (genérico no archivado, envasado, o personalizado propio no eliminado) reutilizando la función que usa `GET /v1/foods/{id}`; comprobarla antes de empezar y, si no existe como función reutilizable, extraerla a `backend/src/mykcal/foods/repository.py`
- [X] T042 [US2] Añadir a `backend/src/mykcal/diary/service.py` `create_entry(...)`: lee el alimento (si no es visible, `FOOD_NOT_FOUND`), resuelve la cantidad, copia el alimento (R5), guarda y devuelve `get_day` de `date`. Registra `diary_entry_created` con `user_id`, `meal` y `duration_ms`, sin nombre, cantidad, fecha ni valores (R12)
- [X] T043 [US2] Añadir a `backend/src/mykcal/diary/router.py` `POST /v1/diary/entries` (`201`, `DiaryDay`). Hace pasar T036 y T037

### Implementación — app

- [X] T044 [P] [US2] Añadir a `app/lib/l10n/app_es.arb` los textos de la hoja: «Añadir a {comida}», «Cantidad», «raciones», «1 ración = {n} g», «Indica una cantidad mayor que 0», «Máximo 10.000», «¿Seguro? Son {n} {unidad}», «Cambiar», «Sí, añadir», «Añadir», «Sin conexión. Revisa la red y vuelve a intentarlo»
- [X] T045 [US2] En `app/lib/features/foods/food_search_screen.dart` y `app/lib/features/foods/barcode_result_flow.dart` añadir el parámetro opcional `onSelected` (modo selección): tocar un resultado, o un «encontrado» del escáner, llama a `onSelected(food)` en lugar de abrir el detalle. «Crear alimento» sigue disponible y devuelve el personalizado creado. Tests de la 003 en `app/test/foods/` siguen en verde
- [X] T046 [US2] Crear `app/lib/features/diary/entry_quantity_sheet.dart` en modo añadir (`contracts/ui-flows.md` §2): campo de cantidad, selector g/ml ↔ raciones, vista previa en vivo con `entry_math.dart`, validación, confirmación > 5.000 y conservar lo escrito si falla la red. Al guardar llama a `addEntry` y aplica la respuesta con `DiaryDayController.apply`. Hace pasar T038
- [X] T047 [US2] Conectar en `app/lib/features/diary/meal_section.dart` y `diary_screen.dart`: «+» → `FoodSearchScreen(onSelected: …)` → `EntryQuantitySheet`. Hace pasar T039

**Checkpoint**: US1 + US2 funcionan: se puede registrar el día. Los escenarios 1–7 de `quickstart.md` pasan.

---

## Phase 5: User Story 3 — Editar y borrar entradas (P1)

**Goal**: cambiar la cantidad de una entrada, moverla a otra comida del mismo día o borrarla, con deshacer durante 10 s.

**Independent Test**: editar la cantidad, mover y borrar entradas y comprobar los totales; deshacer a los 5 s recupera la entrada con los mismos valores.

### Tests (escribir primero)

- [X] T048 [P] [US3] Ampliar `backend/tests/integration/test_diary_entries.py` (FR-005): `PATCH` cambia la cantidad y recalcula con la **copia** guardada (Q7: tras cambiar el alimento su ración a 40 g, `servings: 3` da 90 g con la ración de 30 g); enviar `quantity` pone `servings = NULL` (Q6); enviar `servings` en una entrada registrada en g con ración recalcula `quantity`; `PATCH` con `meal` mueve a otra comida del mismo día y los totales por comida cambian (M2); `PATCH` sin campos, con `date`, o con `quantity` y `servings` a la vez → `400`; `DELETE` marca `deleted_at` y devuelve el día sin la entrada; `restore` antes de 60 s la devuelve **con los mismos valores** aunque el alimento haya cambiado; `restore` a los 61 s, de una entrada no borrada o de otro usuario → `404 ENTRY_NOT_FOUND` (usar el reloj inyectable `clock.utcnow`)
- [X] T049 [P] [US3] Ampliar `backend/tests/contract/test_diary_contract.py`: respuestas de `POST`, `PATCH`, `DELETE` y `restore` validan contra `DiaryDay`; `404 ENTRY_NOT_FOUND` valida contra `ErrorBody`
- [X] T050 [P] [US3] Test de widgets `app/test/diary/entry_quantity_sheet_test.dart` — modo editar (clarificación 2, US3.1, US3.3): una entrada con `servings` se abre en «2 raciones» y permite pasar a g; guardar en g la deja en g; el selector de comida ofrece las 5 y mover cambia los totales; la vista previa usa `DiaryEntry.per100` y `servingSize` de la entrada, no el alimento actual (FR-004); «Guardar» envía `PATCH` y «Borrar» envía `DELETE`; con la red caída, «Guardar» y «Borrar» mantienen la hoja abierta con lo escrito y muestran «Sin conexión» con «Reintentar»
- [X] T051 [P] [US3] Test de widgets `app/test/diary/undo_delete_test.dart` (US3.4, clarificación 3): tras borrar aparece un `SnackBar` de **10 s** («Pan integral borrado» con «Deshacer»); «Deshacer» llama a `restoreEntry` y el diario vuelve a actualizarse; si falla, «No se pudo deshacer»; pasados 10 s el aviso desaparece y no se llama a `restoreEntry`; con el foco de accesibilidad en el aviso no se cierra solo (usar `FakeAsync`); si «Deshacer» falla por falta de red, muestra «No se pudo deshacer» y el diario no cambia

### Implementación — backend

- [X] T052 [US3] Añadir a `backend/src/mykcal/diary/repository.py` `get_entry(session, user_id, entry_id, include_deleted=False)` (siempre con `user_id`; una entrada ajena o inexistente da `None`), `update_entry`, `soft_delete` y `restore`
- [X] T053 [US3] Añadir a `backend/src/mykcal/diary/service.py`: `update_entry` (usa `resolve_quantity` con la `serving_size` **de la entrada**; no toca `entry_date`, `food_*` ni los nutrientes), `delete_entry` (`deleted_at = now()`) y `restore_entry` (solo si `now − deleted_at ≤ 60 s`, si no `ENTRY_NOT_FOUND`), todos devolviendo `get_day` del día de la entrada. Registran `diary_entry_updated`, `diary_entry_deleted` y `diary_entry_restored` con `user_id`, `meal` y `duration_ms` (R12)
- [X] T054 [US3] Añadir a `backend/src/mykcal/diary/router.py` `PATCH /v1/diary/entries/{entry_id}`, `DELETE /v1/diary/entries/{entry_id}` y `POST /v1/diary/entries/{entry_id}/restore` (todas `200 DiaryDay`). Hace pasar T048 y T049

### Implementación — app

- [X] T055 [P] [US3] Añadir a `app/lib/l10n/app_es.arb`: «Guardar», «Borrar», «Comida», «{nombre} borrado», «Deshacer», «No se pudo deshacer»
- [X] T056 [US3] Ampliar `app/lib/features/diary/entry_quantity_sheet.dart` con el modo editar (`contracts/ui-flows.md` §3): unidad inicial según `servings`, selector «Comida», «Guardar» (`updateEntry`) y «Borrar» (`deleteEntry`). Conectar `onTapEntry` de `meal_section.dart`. Hace pasar T050
- [X] T057 [US3] Crear `app/lib/features/diary/undo_delete.dart` (R8): tras `deleteEntry`, aplica la respuesta al diario y muestra el `SnackBar` de 10 s con «Deshacer» que llama a `restoreEntry` y aplica la respuesta. Hace pasar T051

**Checkpoint**: US1–US3 funcionan: el diario de hoy se puede llevar completo. Escenarios 8–11 y 14 de `quickstart.md`.

---

## Phase 6: User Story 4 — Navegar y editar días pasados (P2)

**Goal**: cambiar de día (anterior, siguiente o calendario) y ver y editar cualquier día desde el alta hasta hoy con el objetivo que tenía.

**Independent Test**: ir a un día pasado, añadir y editar entradas, y comprobar que hoy no cambia y que el día pasado usa su objetivo.

### Tests (escribir primero)

- [X] T058 [P] [US4] Ampliar `backend/tests/integration/test_diary_day.py` (FR-010): `GET` de una fecha anterior a `created_at(UTC) − 1 día` o posterior a `hoy(UTC) + 1 día` → `400 DIARY_DATE_OUT_OF_RANGE`; el mismo día del alta y mañana (UTC+1 por margen) → permitidos; lo mismo para `POST /v1/diary/entries` con `date` fuera de rango (reloj inyectable); las entradas añadidas a un día pasado no aparecen en hoy ni en otros días (US4.2)
- [X] T059 [P] [US4] Test unitario `backend/tests/unit/test_diary_dates.py`: `validate_entry_date(day, registered_at, now)` acepta el rango y rechaza fuera de él con los márgenes de R1
- [X] T060 [P] [US4] Test de widgets `app/test/diary/day_header_test.dart` (US4.1, US4.4, FR-010): título «Hoy», «Ayer» o la fecha completa («sábado 22 nov»); «›» desactivado en hoy; «‹» desactivado en el día del alta (`Me.registeredAt` en fecha local); 📅 abre `showDatePicker` con `firstDate` = alta y `lastDate` = hoy; en un día pasado aparece «Ir a hoy»; cada botón con área ≥ 48 dp y etiqueta semántica; en un día pasado la pantalla muestra el aviso «Este día usó el objetivo que tenías entonces» (en hoy no aparece)
- [X] T061 [P] [US4] Test de widgets `app/test/diary/selected_date_test.dart` (edge case medianoche): si el usuario está en «hoy» y al volver a primer plano (`AppLifecycleState.resumed`) la fecha local cambió, pasa al día nuevo; si estaba en un día pasado, no cambia; añadir en un día pasado llama a la API con esa fecha y la respuesta no altera el estado de hoy (US4.2)

### Implementación — backend

- [X] T062 [US4] Añadir a `backend/src/mykcal/diary/day.py` `validate_entry_date(day, registered_at, now)` según R1 (`DIARY_DATE_OUT_OF_RANGE`) y llamarla desde `get_day` y `create_entry` en `diary/service.py`, usando `clock.utcnow` y `UserAccount.created_at`. Hace pasar T058 y T059

### Implementación — app

- [X] T063 [P] [US4] Añadir a `app/lib/l10n/app_es.arb`: «Ayer», fechas largas, «Ir a hoy», «Día anterior», «Día siguiente», «Elegir fecha»
- [X] T064 [US4] Crear `app/lib/features/diary/selected_date.dart` (R13): `StateNotifier<DateTime>` con el día visible; `previous()`, `next()`, `goTo()` limitados a `[alta local, hoy]`; en `didChangeAppLifecycleState(resumed)`, si estaba en «hoy» y cambió la fecha local, pasa al día nuevo. Hace pasar T061
- [X] T065 [US4] Crear `app/lib/features/diary/day_header.dart` con ‹ › 📅 «Ir a hoy» según `contracts/ui-flows.md` §1. Hace pasar T060
- [X] T066 [US4] Integrar en `app/lib/features/diary/diary_screen.dart`: la cabecera, el día de `selectedDateProvider` en `diaryDayControllerProvider`, y el aviso «Este día usó el objetivo que tenías entonces» cuando el día no es hoy. Añadir, editar y borrar usan la fecha visible. Pasar `Me.registeredAt` desde `HomeScreen`

**Checkpoint**: las 4 historias funcionan. Escenarios 15–18 de `quickstart.md`.

---

## Phase 7: Polish y transversal

- [X] T067 [P] Crear `backend/tests/privacy/test_user_isolation_diary.py` (SC-005, principio V): con dos usuarios con consentimiento, B recibe `404 ENTRY_NOT_FOUND` en `PATCH`, `DELETE` y `restore` con el `id` de una entrada de A, y la respuesta es **idéntica** a la de un `id` inexistente; el día de B nunca incluye entradas de A aunque tengan la misma fecha; B no puede añadir un personalizado de A (`404 FOOD_NOT_FOUND`)
- [X] T068 [P] Ampliar `backend/tests/privacy/test_consent_gate.py`: añadir a `HEALTH_DATA_ROUTES` las 5 rutas de `/v1/diary/**`, con sus parámetros (`utc_offset_min`, cuerpo de `POST`) en las constantes de consulta y de cuerpo; sin consentimiento `403 CONSENT_REQUIRED`, sin cuenta `403 ACCOUNT_NOT_REGISTERED`, y desactivada `403 ACCOUNT_DISABLED`
- [X] T069 [P] Ampliar `backend/tests/privacy/test_all_routes_require_identity.py` para que cubra las 5 rutas nuevas (sin token → `401`) y comprobar que no hay rutas públicas nuevas
- [X] T070 [P] Ampliar `backend/tests/privacy/test_logs_no_secrets.py` (principio X, R12): tras crear, editar, borrar y restaurar una entrada, los registros contienen los eventos `diary_entry_*` con `user_id`, `meal` y `duration_ms` y **no** contienen el nombre del alimento, la cantidad, la fecha ni los valores nutricionales
- [X] T071 [P] Test de accesibilidad `app/test/diary/diary_a11y_test.dart`: el diario y la hoja respetan el tamaño de texto al 200 % sin cortarse, todos los controles tienen etiqueta semántica, el contraste de exceso/incompleto cumple WCAG 2.1 AA en claro y oscuro (con `app/test/helpers/a11y.dart`) (FR-014, principio VIII)
- [X] T072 Ejecutar `cd backend && uv run ruff check && uv run pytest` y `cd app && flutter analyze && flutter test`: todo en verde, sin avisos nuevos
- [ ] T073 Recorrer los escenarios 1–21 de `specs/004-diario-de-comidas/quickstart.md` con el backend local y el emulador o móvil, incluido TalkBack y texto al 200 % (escenario 21), y anotar lo que falle
- [X] T074 Actualizar `README.md` si lista las features o las rutas, y revisar que `specs/001-acceso-y-despliegue/contracts/openapi.yaml` 0.4.0 y `plan.md` coinciden con lo implementado
- [ ] T075 Cierre (principio IX): abrir PR de `004-diario-de-comidas` a `dev` con las pruebas en verde; tras el merge a `main` y el despliegue en Dokploy (la migración `0004_diary` corre al arrancar), repetir los escenarios 1, 2, 10 y 16 en el móvil contra producción

---

## Dependencias y orden

- **Phase 1 → Phase 2 → historias → Phase 7.** La Phase 2 bloquea todo lo demás.
- **US1** no depende de otra historia: se prueba con entradas insertadas por `make_entry` (T009).
- **US2** depende de US1 en la app (necesita `DiaryScreen`, `MealSection` y `DiaryDayController`) y de T041 (lectura de alimento visible). En el backend, solo de la Phase 2.
- **US3** depende de US2 en la app (reutiliza `EntryQuantitySheet`) y de T052 en el backend. Las rutas `PATCH`/`DELETE`/`restore` pueden hacerse en paralelo a US2 si se usa `make_entry`.
- **US4** depende de US1 (`DiaryScreen`) y de T062 sobre `get_day`/`create_entry` de US1/US2. Se puede hacer en paralelo a US3.
- Dentro de cada historia: tests → módulos puros → repositorio → servicio → router; en la app, controlador → widgets → pantalla.

### Paralelización

```text
Phase 2:  T002 | T004 | T006 | T009 | T010 | T012 | T014 | T015    (archivos distintos)
US1 tests: T016 | T017 | T018 | T019 | T020 | T021 | T022
US1 impl:  T023 → T024 → T025 → T026 → T027        |   T028 | T030 | T031 | T032 → T033 → T034
US2:       T035 | T036 | T037 | T038 | T039   →   T040 → T041 → T042 → T043   |   T044 | T045 → T046 → T047
US3:       T048 | T049 | T050 | T051   →   T052 → T053 → T054   |   T055 → T056 → T057
US4:       T058 | T059 | T060 | T061   →   T062   |   T063 → T064 → T065 → T066
Polish:    T067 | T068 | T069 | T070 | T071
```

## Estrategia de entrega

1. **MVP = US1**: el diario se ve con datos. Aún no se puede registrar desde la app, pero valida el cálculo (SC-002) y el objetivo por día.
2. **US2** hace la app útil: registrar el día. Es el primer punto utilizable de verdad (principio IX).
3. **US3** cierra el ciclo de uso diario (corregir errores).
4. **US4** (P2) añade el repaso y el registro de días pasados. Si el plazo aprieta, es lo primero que se puede recortar sin romper el uso de hoy.
5. Fusionar en `dev` solo con las 4 historias y la Phase 7 en verde.
