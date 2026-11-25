# Tasks: Peso y recálculo del objetivo

**Input**: Design documents from `specs/007-peso-y-recalculo/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R9), data-model.md, contracts/ (`api-changes.md`, `average-cases.md`, `ui-flows.md`), quickstart.md

**Tests**: se incluyen. Se sigue la práctica de 001–006 (test primero) y el principio VI (cálculo determinista con casos conocidos, FR-009) y IV/V (privacidad y aislamiento con pruebas automáticas). Los tests de cada historia se escriben antes y deben fallar.

**Organization**: por historia de usuario. Lo común (media/umbral puros, migración, modelo, errores, esquemas, contrato, textos y base de la app) está en la Phase 2. Orden por prioridad: US1 registrar peso (P1) → US3 propuesta de recálculo (P1) → US2 gráfica (P2). US3 y US2 dependen solo de la Phase 2 y de poder tener registros de peso (los tests los crean con `make_weight`), así que son independientes de US1 en código; en la práctica se hacen en este orden.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de `spec.md` (US1 registrar peso, US2 gráfica, US3 propuesta de recálculo)
- Rutas de backend relativas a `backend/src/mykcal/` salvo que se indique `backend/tests/` o `backend/alembic/`; las de la app, a `app/`.

---

## Phase 1: Setup

- [X] T001 Comprobar que la rama es `007-peso-y-recalculo` y que `cd backend && uv run ruff check && uv run pytest` y `cd app && flutter analyze && flutter test` pasan antes de empezar (línea base de 006/008/009)
- [X] T002 Añadir `fl_chart` a las dependencias de `app/pubspec.yaml` con `cd app && flutter pub add fl_chart` (versión estable más reciente; consultar su API con Context7 al usarla en T040) y comprobar que `flutter analyze` sigue en verde

---

## Phase 2: Foundational (bloquea todas las historias)

### Cálculo puro de media y umbral (R3, FR-004, FR-009, SC-002)

- [X] T003 [P] Crear `backend/tests/unit/test_weight_average.py` (`pytest.mark.parametrize`, sin base de datos) con **todas** las filas de `specs/007-peso-y-recalculo/contracts/average-cases.md`: `weekly_average` (suficientes, redondeo HALF_UP `78.166…→78.2` y `78.15→78.2`, exactamente 3 registros, menos de 3 → `None`, registro a 8 días fuera de la ventana, solo hoy → `None`), `exceeds_threshold` (78.2 → True, 78.6 → False, **78.4 vs 80.0 = exactamente 2% → False**, 78.3 → True, 81.7 → True, 81.6 → False, 71.0 → True) y `moving_average_series` (ventana con 3, ventana con 2 → `None`, primer registro → media `None`, y **ventana que cruza `since`**: el primer día del periodo con 2 registros previos a `since` dentro de su ventana → media calculada con 3 registros). Debe fallar
- [X] T004 Crear `backend/src/mykcal/weight/__init__.py` (vacío) y `backend/src/mykcal/weight/average.py`: funciones **puras**, sin E/S, sin reloj y sin `float` (`Decimal`, `ROUND_HALF_UP`, mismo estilo que `targets/calc.py`). `weekly_average(entries, as_of) -> Decimal | None`: media de los `weight_kg` con `measured_on` en `[as_of − 6 días, as_of]`, `None` con menos de 3 registros, resultado cuantizado a **1 decimal, medio hacia arriba**. `exceeds_threshold(average, reference) -> bool`: `abs(average − reference) / reference > Decimal("0.02")` (**estrictamente mayor**). `is_large_change(average, reference) -> bool`: `> Decimal("0.10")`. `moving_average_series(entries, since) -> list[tuple[date, Decimal, Decimal | None]]`: una tupla `(fecha, peso, media)` por cada día **con registro** desde `since` (o todos si `None`), con la media móvil de su ventana de 7 días solo si hay ≥3 registros; `entries` incluye **todos** los registros, también los anteriores a `since`: `since` solo filtra qué días se devuelven, no la ventana de la media; sin interpolar días sin registro. Hace pasar T003

### Base de datos y modelos (R5, data-model.md)

- [X] T005 [P] Añadir a `backend/tests/integration/test_migrate.py` los casos de `0007_weight_recalc` (suben y bajan): `recalc_proposal` con `status` fuera de `pending|accepted|ignored` → error (`ck_recalc_status`); `status='pending'` con `responded_at` no nulo, o `status<>'pending'` con `responded_at` nulo → error (`ck_recalc_responded`); `ignored_until` no nulo con `status<>'ignored'` → error (`ck_recalc_ignored_until`); **dos filas `pending` del mismo usuario → error** (`uq_recalc_pending`); `user_id` o `target_from_id` inexistente → error (FK); `downgrade -1` elimina `recalc_proposal` y `ix_weight_entry_user_date`
- [X] T006 Crear `backend/alembic/versions/0007_weight_recalc.py` (`revision = "0007_weight_recalc"`, `down_revision = "0006_ai_key"` — 006 ya ocupó la 0006, con `downgrade`), constraints verbatim de `data-model.md`:
  - Tabla `recalc_proposal`: `id uuid PK server_default gen_random_uuid()`, `user_id uuid NOT NULL FK user_account.id`, `status text NOT NULL`, `reference_weight_kg numeric(4,1) NOT NULL`, `weekly_average_kg numeric(4,1) NOT NULL`, `target_from_id uuid NOT NULL FK daily_target.id`, `was_manual boolean NOT NULL`, `created_at timestamptz NOT NULL`, `responded_at timestamptz NULL`, `ignored_until date NULL`
  - `ck_recalc_status`: `status IN ('pending','accepted','ignored')`
  - `ck_recalc_responded`: `(responded_at IS NULL) = (status = 'pending')`
  - `ck_recalc_ignored_until`: `ignored_until IS NULL OR status = 'ignored'`
  - Índice único parcial `uq_recalc_pending (user_id) WHERE status = 'pending'`
  - Índice `ix_recalc_user_created (user_id, created_at)`
  - Índice `ix_weight_entry_user_date (user_id, measured_on)` sobre `weight_entry` (si ya existe uno equivalente por la restricción única `uq_weight_entry_user_day`, omitir este y anotarlo en el docstring)
  - Hace pasar T005
- [X] T007 [P] Crear `backend/src/mykcal/weight/models.py` con `RecalcProposal` (SQLAlchemy 2, mismo estilo que `quick/models.py`, `Numeric(4, 1)` para los pesos, `Date` para `ignored_until`) y los mismos `CheckConstraint` e índices de T006; registrar el módulo donde `backend/alembic/env.py` y `backend/tests/conftest.py` cargan el metadata. `WeightEntry` **no** se mueve: se importa de `mykcal.profile.models` (R1)

### Errores, esquemas, rutas y contrato

- [X] T008 [P] En `backend/src/mykcal/core/errors.py` añadir a `ErrorCode`: `WEIGHT_NOT_FOUND` (404) y `RECALC_NO_PROPOSAL` (409)
- [X] T009 [P] Crear `backend/src/mykcal/weight/schemas.py` (Pydantic v2, `extra="forbid"` en las entradas) según `contracts/api-changes.md`: `WeightInput` (`measured_on: date`, `weight_kg: Weight` reutilizando el tipo `Weight` de `targets/schemas.py`: **30–300 kg, un decimal como máximo**), `WeightUpdate` (solo `weight_kg`), `WeightEntry` (`measured_on`, `weight_kg: float`, `updated_at`), `WeightList` (`entries`), `WeightChartPoint` (`date`, **`weight_kg: float` obligatorio** porque solo hay puntos de días con registro, `average_kg: float | None`), `WeightChartSummary` (`count: int`, `current_weight_kg`, `weekly_average_kg`, `change_kg`, los tres `float | None`), `WeightChart` (`period: Literal["p30","p90","all"]`, `points`, `summary`) y `RecalcProposal` (`status: Literal["pending","none"]`, `reference_weight_kg`, `weekly_average_kg`, `was_manual`, `large_change`, `current: TargetValues | None`, `proposed: TargetValues | None`). Ajustar también `specs/007-peso-y-recalculo/contracts/api-changes.md`: `WeightChartPoint.weight_kg` pasa a no nulable
- [X] T010 Crear `backend/src/mykcal/weight/router.py` con `APIRouter()` cuyas rutas dependen de `require_consent` (datos de salud, principio IV) y registrarlo en `backend/src/mykcal/main.py` (`include_router(weight_router)`) junto al resto. Las rutas las añaden las historias; cada una añade las suyas al conjunto cerrado de `backend/tests/privacy/test_all_routes_require_identity.py` (T021, T032 y T039), para que ese test no falle entre fases
- [X] T011 Actualizar `specs/001-acceso-y-despliegue/contracts/openapi.yaml` con el «Fragmento OpenAPI» de `specs/007-peso-y-recalculo/contracts/api-changes.md`: 8 rutas (`GET`/`POST /v1/weight`, `PUT`/`DELETE /v1/weight/{date}`, `GET /v1/weight/chart`, `GET /v1/recalc-proposal`, `POST /v1/recalc-proposal/accept`, `POST /v1/recalc-proposal/ignore`), schemas `WeightInput`, `WeightEntry`, `WeightList`, `WeightChartPoint`, `WeightChart`, `RecalcProposal`, `WEIGHT_NOT_FOUND` y `RECALC_NO_PROPOSAL` en el enum de `ErrorBody.code`, y `info.version: 0.7.0`
- [X] T012 (depende de T007) En `backend/tests/conftest.py` añadir `make_weight(user, measured_on, weight_kg, ...)` que inserta un `WeightEntry`, y `make_proposal(user, target, status="pending", ...)` que inserta una `RecalcProposal`

### Base de la app

- [X] T013 [P] En `app/lib/core/api/models.dart` añadir `WeightEntry`, `WeightChartPoint`, `WeightChartSummary`, `WeightChart` y `RecalcProposal` (con `current`/`proposed` como `TargetValues?`) con `fromJson` según `contracts/api-changes.md`
- [X] T014 (depende de T013) En `app/lib/core/api/mykcal_api.dart` añadir a `MykcalApi` y a `HttpMykcalApi`: `weightEntries()`, `saveWeight(DateTime day, double kg, int utcOffsetMin)`, `updateWeight(DateTime day, double kg)`, `deleteWeight(DateTime day)`, `weightChart(String period, int utcOffsetMin)`, `recalcProposal(int utcOffsetMin)`, `acceptRecalc()` y `ignoreRecalc()`; actualizar los fakes de `app/test/helpers/fakes.dart`. Test de cliente en `app/test/api/weight_api_test.dart` para el mapeo de `VALIDATION_ERROR`, `WEIGHT_NOT_FOUND` y `RECALC_NO_PROPOSAL`
- [X] T015 [P] Añadir los textos de la feature a `app/lib/l10n/app_es.arb` y regenerar con `cd app && flutter gen-l10n`: título «Peso», etiqueta del campo y del selector de fecha, «Guardar», «Sustituye el peso de ese día», `errWeightFutureDate` («No puedes registrar un peso en una fecha futura»), confirmación de borrado, lista vacía; periodos «30 días»/«90 días»/«Todo»; resumen accesible (peso actual, media semanal, variación en el periodo), «Necesitas al menos 2 registros para ver la gráfica»; propuesta (título, «Objetivo actual», «Objetivo propuesto», «Aceptar», «Ignorar», aviso de objetivo editado a mano «Aceptar sustituirá los valores que editaste», aviso de variación grande «Revisa si hay un registro erróneo»); `menuWeight`. Reutilizar `errWeightRange` ya existente

**Checkpoint**: T003 y T005 en verde; `alembic upgrade head` y `downgrade -1` funcionan; el contrato 0.6.0 es válido; T014 en verde; `flutter test` verde.

---

## Phase 3: User Story 1 - Registrar el peso (Priority: P1) 🎯 MVP

**Goal**: el usuario anota su peso del día (o de un día pasado), lo corrige y lo borra; un registro por día; rango 30–300 kg; sin fechas futuras.

**Independent Test**: registrar, sustituir, corregir y borrar pesos y comprobar la lista (escenario V1 de `quickstart.md`).

### Tests for User Story 1 ⚠️ (escribirlos primero; deben fallar)

- [X] T016 [P] [US1] Crear `backend/tests/integration/test_weight_entries.py` con `make_weight`: `POST /v1/weight` crea el registro de hoy (78.4); un segundo `POST` el mismo día lo **sustituye** (un solo registro, `updated_at` cambia); `POST` en un día pasado sin registro lo crea; `PUT /v1/weight/{date}` edita; `DELETE` → 204 y desaparece de `GET /v1/weight`; `PUT`/`DELETE` de un día sin registro → 404 `WEIGHT_NOT_FOUND`; `weight_kg` = 29.9 y 300.1 → 400 `VALIDATION_ERROR` con `fields=["weight_kg"]`, 30.0 y 300.0 válidos; más de un decimal → 400; todas las peticiones llevan `utc_offset_min` (sin él → 400); fecha posterior al «hoy» **local** (`hoy = (now UTC + utc_offset_min).date()`) → 400 `VALIDATION_ERROR` con `fields=["measured_on"]` (p. ej. con `utc_offset_min=-600` y la hora UTC en la madrugada, el día local anterior sigue siendo válido y el día siguiente local → 400) y anterior a `fecha de alta (UTC) − 1 día` → 400 igual (R2, FR-001; **no** `DIARY_DATE_OUT_OF_RANGE`); `GET /v1/weight?from=&to=` filtra y ordena por fecha descendente; sin consentimiento → 403 `CONSENT_REQUIRED`
- [X] T017 [P] [US1] Crear `backend/tests/contract/test_weight_contract.py` (mismo patrón que `test_quick_contract.py`): `POST`/`GET`/`PUT`/`DELETE` de peso validan sus respuestas contra `openapi.yaml` (T011) y los códigos de error documentados
- [X] T018 [P] [US1] Crear `backend/tests/privacy/test_user_isolation_weight.py` (mismo patrón que `test_user_isolation_quick.py`): el usuario B no ve en `GET /v1/weight` los registros de A, y `PUT`/`DELETE /v1/weight/{date}` de una fecha que solo tiene A devuelve 404 `WEIGHT_NOT_FOUND` a B sin modificar nada (FR-010). Añadir el peso a `backend/tests/privacy/test_consent_gate.py` y `test_disabled_account.py` si enumeran rutas a mano
- [X] T019 [P] [US1] Añadir a `backend/tests/privacy/test_logs_no_secrets.py` un caso: tras `POST /v1/weight` con un peso reconocible (p. ej. 83.7), ninguna línea de log contiene `83.7` ni la fecha del registro (principio X)

### Implementation for User Story 1

- [X] T020 [US1] Crear `backend/src/mykcal/weight/service.py` con `list_entries(session, user_id, date_from, date_to)`, `upsert_entry(session, user_id, account, data, now)` (valida la fecha con un validador propio `validate_measured_on(day, registered_at, now, utc_offset_min)` (R2, FR-001): `ApiError(400, ErrorCode.VALIDATION_ERROR, "Petición no válida.", fields=["measured_on"])` si `day > (now + timedelta(minutes=utc_offset_min)).date()` o `day < registered_at.astimezone(UTC).date() − 1 día` (mismo patrón que `profile/service.py`; no se reutiliza `diary.day.validate_entry_date` porque lanza `DIARY_DATE_OUT_OF_RANGE`); `utc_offset_min` es un parámetro obligatorio en las firmas; `insert(...).on_conflict_do_update(constraint="uq_weight_entry_user_day", set_={"weight_kg": ..., "updated_at": now})`, como `profile/service.py`), `update_entry(...)` y `delete_entry(...)`; los dos últimos lanzan `ApiError(404, ErrorCode.WEIGHT_NOT_FOUND, "No hay peso registrado ese día.")` si no existe. **Todas** filtran por `user_id`. Log `structlog.get_logger("mykcal").info("weight_saved")` sin valores (principio X). No hace commit (lo hace el router). Hace pasar T016
- [X] T021 [US1] En `backend/src/mykcal/weight/router.py` añadir `GET /v1/weight` (`WeightList`), `POST /v1/weight` (`WeightEntry`, hace `commit`), `PUT /v1/weight/{date}` y `DELETE /v1/weight/{date}` (`204`), los tres con `utc_offset_min: int = Query(ge=-840, le=840)` **obligatorio** (igual que `UtcOffsetMin` de `diary/router.py`), con `require_consent` y `ApiError` para los errores. Añadir `("GET", "/v1/weight")`, `("POST", "/v1/weight")`, `("PUT", "/v1/weight/{date}")` y `("DELETE", "/v1/weight/{date}")` al conjunto cerrado de `backend/tests/privacy/test_all_routes_require_identity.py`. Hace pasar T017 y T018

### App for User Story 1

- [X] T022 [P] [US1] Crear `app/lib/features/weight/weight_controller.dart` (Riverpod, mismo patrón que `diary_day_controller.dart`): estado con la lista de registros, `save(day, kg)`, `update(day, kg)` y `delete(day)`; la fecha por defecto y el máximo son la **fecha local del móvil** (`features/diary/local_day.dart`), y `utcOffsetMin` se calcula como en el diario. Si falla la red, el estado conserva el valor escrito (R9) y expone el error
- [X] T023 [US1] (depende de T022) Crear `app/lib/features/weight/weight_screen.dart`: campo numérico en kg con un decimal y validación 30–300 (`errWeightRange`), selector de fecha con hoy por defecto que **no permite fechas futuras**, botón «Guardar», lista de registros (fecha + peso) con editar y borrar por fila (borrar pide confirmación), aviso breve cuando se sustituye un registro del mismo día, y aviso de falta de conexión sin vaciar el campo. Todos los controles con `Semantics`/etiqueta, tamaño de texto del sistema y tema claro/oscuro (FR-011)
- [X] T024 [US1] En `app/lib/features/home/home_screen.dart` añadir la acción `weight` («Peso») al menú ⋮ (`_MenuAction.weight`, `l10n.menuWeight`) que abre `WeightScreen` (SC-001: registrar en menos de 10 s desde la pantalla principal)
- [X] T025 [P] [US1] Crear `app/test/weight/weight_screen_test.dart`: guardar 78,4 llama a la API con el día de hoy; peso 25 o 310 muestra `errWeightRange` y no llama a la API; el selector no ofrece fechas futuras; editar y borrar (con confirmación) actualizan la lista; con la API caída el campo conserva el valor; los controles tienen etiqueta semántica

### Borrar el registro del onboarding (edge case de la spec)

- [X] T048 [P] [US1] Crear `backend/tests/integration/test_weight_delete_profile.py`: un usuario con perfil y objetivo calculado con 80 kg y **un único** `WeightEntry` (el del onboarding); tras `DELETE /v1/weight/{date}` (204), `GET /v1/profile` sigue respondiendo 200 con `weight_kg = 80.0` (el `calc_weight_kg` del objetivo vigente) y `weight_measured_on = calculated_at.date()`, `POST /v1/target/recalculate` responde 200 usando 80 kg, y `GET /v1/target` no cambia. Con un registro nuevo posterior, `GET /v1/profile` vuelve a usar el último registro. Debe fallar
- [X] T049 [US1] En `backend/src/mykcal/profile/service.py` añadir `current_weight(session, user_id) -> tuple[Decimal, date] | None`: el último `WeightEntry` si existe; si no, `(calc_weight_kg, calculated_at.date())` del objetivo vigente (`targets.current_target`); `None` solo si tampoco hay objetivo. Usarlo en `get_profile` (en lugar de `latest_weight`, ajustando `_profile_out` para recibir peso y fecha) y en `calc_data_now`, para que borrar el único registro no rompa Ajustes → perfil ni `POST /v1/target/recalculate` (spec «Borrar el registro del onboarding»). `save_profile` sigue usando `latest_weight` (con `None` fuerza el recálculo, como ahora). Hace pasar T048 y no rompe `backend/tests/integration/test_onboarding.py`

**Checkpoint**: US1 completa y usable en el móvil: registrar, sustituir, corregir y borrar pesos (V1 de `quickstart.md`).

---

## Phase 4: User Story 3 - Propuesta de recálculo del objetivo (Priority: P1)

**Goal**: cuando la media semanal difiere más de un 2% del peso usado en el último cálculo (con ≥3 registros en 7 días), la app propone recalcular; aceptar recalcula con la media semanal; ignorar no vuelve a proponer durante 7 días; una propuesta sin responder sigue pendiente y se vuelve a mostrar.

**Independent Test**: con registros preparados que superen y que no superen el umbral, comprobar que la propuesta aparece solo cuando corresponde y que aceptar e ignorar funcionan (escenario V3 de `quickstart.md`).

### Tests for User Story 3 ⚠️ (escribirlos primero; deben fallar)

- [X] T026 [P] [US3] Crear `backend/tests/integration/test_recalc_proposal.py` con `make_weight`, `make_proposal` y un objetivo calculado con 80 kg (`calc_weight_kg`): media 78.2 con ≥3 registros en 7 días → `GET /v1/recalc-proposal` devuelve `pending` con `reference_weight_kg=80.0`, `weekly_average_kg=78.2`, `current` y `proposed` (el propuesto = `targets.calc.calculate` con perfil vigente y peso 78.2); media 78.6 → `none`; **un solo registro de 76 kg → `none`** (SC-003); exactamente 2,0% (78.4) → `none`; llamar dos veces devuelve la misma propuesta y **no crea una segunda fila** (una sola `pending`, FR-007/US3.7); si cambian los registros entre dos llamadas la fila `pending` se actualiza (`weekly_average_kg`); si al reevaluar ya no se supera el umbral la fila `pending` desaparece; variación >10% → `large_change=true`; objetivo `source='manual'` → `was_manual=true`; `POST /accept` recalcula (nueva versión de `daily_target` con `source='calculated'`, `calc_weight_kg=78.2`, `effective_from=ahora`), marca la fila `accepted` con `responded_at`, y los días pasados del diario conservan su objetivo (R8); tras aceptar, `GET` devuelve `none` (la referencia ahora es 78.2); `POST /ignore` marca `ignored` con `ignored_until = hoy + 7 días` y `GET` devuelve `none` mientras `hoy < ignored_until`, y vuelve a proponer cuando `hoy >= ignored_until` y se sigue superando; `accept`/`ignore` sin propuesta → 409 `RECALC_NO_PROPOSAL`; guardar, editar o borrar un peso reevalúa la propuesta (US3 «Registro de un día pasado»); **un objetivo editado a mano no cambia sin `accept`** (SC-004); **dos `GET /v1/recalc-proposal` concurrentes** (`asyncio.gather`, sesiones distintas) con el umbral superado → ambos 200 y una sola fila `pending`
- [X] T027 [P] [US3] Añadir `RecalcProposal` y las 3 rutas de propuesta a `backend/tests/contract/test_weight_contract.py` (validar contra `openapi.yaml`, incluido que `current`/`proposed` se omiten con `status=none`)
- [X] T028 [P] [US3] Crear `backend/tests/privacy/test_user_isolation_recalc.py`: la propuesta de A no aparece en `GET /v1/recalc-proposal` de B; `accept`/`ignore` de B con propuesta solo de A → 409 `RECALC_NO_PROPOSAL` sin tocar el objetivo de A (FR-010, principio V)

### Implementation for User Story 3

- [X] T029 [US3] En `backend/src/mykcal/weight/service.py` añadir `evaluate_proposal(session, user_id, today, now) -> RecalcProposal | None`, con `today` = fecha local del móvil (`(now UTC + utc_offset_min).date()`), siguiendo `research.md` R5:
  1. `current = targets.current_target(...)`; sin objetivo → `None`.
  2. `avg = weekly_average(registros de [today−6, today], today)`; si `avg is None` o `not exceeds_threshold(avg, current.calc_weight_kg)` → **borrar** la fila `pending` del usuario si existe (no hay estado «cancelada»; anotar la decisión en `research.md` R5) y devolver `None`.
  3. Si hay fila `pending`: actualizar `reference_weight_kg`, `weekly_average_kg`, `target_from_id` y `was_manual` y devolverla.
  4. Si existe una fila `ignored` con `ignored_until > today` → `None` (bloqueada hasta `ignored_until`).
  5. Si no: insertar `pending` (`created_at=now`) con `insert(RecalcProposal).on_conflict_do_update(index_elements=["user_id"], index_where=text("status = 'pending'"), set_={referencia, media, target_from_id, was_manual})` sobre el índice único parcial `uq_recalc_pending`, para que dos evaluaciones simultáneas (abrir la app y guardar un peso) no den un 500 ni dupliquen la fila.
  
  Calcular `proposed` con `targets.service.values_from_result(calculate(profile.calc_data_now(session, user_id, weight_kg=avg).inputs()))` y `current` con `TargetValues.model_validate(current)`, sin guardarlos en la tabla (data-model.md). `large_change = is_large_change(avg, reference)`. Log `recalc_proposed` sin valores
- [X] T030 [US3] En `backend/src/mykcal/weight/service.py` añadir `accept_proposal(session, user_id, today, now)`: reevaluar con `evaluate_proposal`; si no hay `pending` → `ApiError(409, ErrorCode.RECALC_NO_PROPOSAL, "No hay ninguna propuesta pendiente.")`; si la hay, `targets.service.recalculate(session, user_id, await profile.service.calc_data_now(session, user_id, weight_kg=fila.weekly_average_kg), now)` (la media semanal pasa a ser `calc_weight_kg`, FR-006; el objetivo nuevo rige desde hoy, R8), poner `status='accepted'` y `responded_at=now`, y devolver el objetivo vía `targets.service.to_out`. Log `recalc_accepted`. Y `ignore_proposal(...)`: misma comprobación, `status='ignored'`, `responded_at=now`, `ignored_until=today + 7 días`; log `recalc_ignored`
- [X] T031 [US3] En `backend/src/mykcal/weight/service.py` reevaluar la propuesta tras `upsert_entry`, `update_entry` y `delete_entry` de US1 (llamar a `evaluate_proposal` en la misma transacción, con el `utc_offset_min` recibido; `PUT`/`DELETE` reciben `utc_offset_min` obligatorio, como `POST`) para que el umbral se compruebe «al registrar un peso» (supuesto de la spec) y se repita al guardar un día pasado
- [X] T032 [US3] En `backend/src/mykcal/weight/router.py` añadir `GET /v1/recalc-proposal` (acepta `utc_offset_min`; devuelve `{"status": "none"}` o la propuesta, con `response_model_exclude_none=True`), `POST /v1/recalc-proposal/accept` (`DailyTarget`) y `POST /v1/recalc-proposal/ignore` (`204`), con `require_consent` y `commit`; `utc_offset_min` obligatorio (`Query(ge=-840, le=840)`) en `GET /v1/recalc-proposal`. Añadir `("GET", "/v1/recalc-proposal")`, `("POST", "/v1/recalc-proposal/accept")` y `("POST", "/v1/recalc-proposal/ignore")` al conjunto cerrado de `backend/tests/privacy/test_all_routes_require_identity.py`. Hace pasar T026–T028

### App for User Story 3

- [X] T033 [P] [US3] Crear `app/lib/features/weight/recalc_proposal_dialog.dart`: diálogo (patrón de `showTargetUpdatedDialog` de `features/target/recalc_dialogs.dart`, reutilizando `macroLine`) con «Objetivo actual» y «Objetivo propuesto» en texto, media semanal y peso de referencia, aviso de objetivo editado a mano cuando `wasManual` y aviso de revisar un posible registro erróneo cuando `largeChange`; botones «Aceptar» (con `autofocus`) e «Ignorar» etiquetados; el foco entra en el diálogo y el contenido se lee como texto (FR-011)
- [X] T034 [US3] (depende de T033) Crear `app/lib/features/weight/recalc_proposal_controller.dart` (Riverpod): `check()` llama a `recalcProposal(utcOffsetMin)`, y si es `pending` muestra el diálogo; «Aceptar» llama a `acceptRecalc()`, muestra el resultado antes → ahora con `showTargetUpdatedDialog` e invalida los providers del objetivo y del diario; «Ignorar» llama a `ignoreRecalc()`; cerrar sin responder no llama a nada (la propuesta sigue `pending`, US3.7). Un `RECALC_NO_PROPOSAL` se trata como «ya resuelta» sin error
- [X] T035 [US3] Llamar a `check()` de T034 al abrir la app (en `HomeScreen`, una vez tras mostrar el diario, `features/home/home_screen.dart`) y tras guardar, editar o borrar un peso en `WeightScreen` (`features/weight/weight_screen.dart`)
- [X] T036 [P] [US3] Crear `app/test/weight/recalc_proposal_test.dart`: con `pending` se muestra el diálogo con actual y propuesto; «Aceptar» llama a `acceptRecalc` y refresca el objetivo; «Ignorar» llama a `ignoreRecalc` y no reaparece; cerrar sin responder no llama a la API; con `none` no aparece nada; avisos de `wasManual` y `largeChange` visibles; botones con etiqueta semántica

**Checkpoint**: US3 completa: propuesta, aceptar, ignorar y persistencia en servidor (V3 de `quickstart.md`).

---

## Phase 5: User Story 2 - Ver la gráfica de peso (Priority: P2)

**Goal**: el usuario ve sus pesos diarios y la media semanal en periodos de 30 días, 90 días y todo, con alternativa textual accesible.

**Independent Test**: con registros de varias semanas, comprobar la gráfica en cada periodo y su alternativa textual (escenario V2 de `quickstart.md`).

### Tests for User Story 2 ⚠️ (escribirlos primero; deben fallar)

- [X] T037 [P] [US2] Crear `backend/tests/integration/test_weight_chart.py`: con registros de varias semanas, `GET /v1/weight/chart?period=p30` devuelve solo los puntos de los últimos 30 días (`hoy−29 … hoy`, con `utc_offset_min`), `p90` los de 90 y `all` desde el primer registro; cada punto es un día **con** registro y los días sin registro no aparecen (sin interpolar); `average_kg` es `null` en los días cuya ventana de 7 días tiene menos de 3 registros y coincide con `weekly_average` en el resto; el resumen trae `count`, `current_weight_kg` (último registro del periodo), `weekly_average_kg` (media semanal de hoy, `null` con menos de 3 registros) y `change_kg` (último − primero del periodo, `null` con menos de 2 registros); el primer día de `p30` tiene `average_kg` si 2 de los registros de su ventana son anteriores al periodo; un periodo inválido → 400 `VALIDATION_ERROR`; con menos de 2 registros el endpoint responde 200 con `points` cortos (el mensaje lo muestra la app)
- [X] T038 [P] [US2] Añadir `WeightChart` a `backend/tests/contract/test_weight_contract.py` y el caso de aislamiento de la gráfica a `backend/tests/privacy/test_user_isolation_weight.py` (la gráfica de B no incluye registros de A)

### Implementation for User Story 2

- [X] T039 [US2] En `backend/src/mykcal/weight/service.py` añadir `chart(session, user_id, period, today)`: calcula `since` (`today−29`, `today−89` o `None`), carga los registros del usuario **sin recortar por `since`** (la ventana de 7 días de los primeros días del periodo usa registros anteriores a él), usa `moving_average_series` de T004 (una sola implementación de la media, R4) y arma el `WeightChart` con el resumen descrito en T037. En `backend/src/mykcal/weight/router.py` añadir `GET /v1/weight/chart` (`period` obligatorio con enum `p30|p90|all`, `utc_offset_min` opcional), con `utc_offset_min` obligatorio. Añadir `("GET", "/v1/weight/chart")` al conjunto cerrado de `backend/tests/privacy/test_all_routes_require_identity.py`. Hace pasar T037 y T038

### App for User Story 2

- [X] T040 [P] [US2] Crear `app/lib/features/weight/weight_chart.dart` con `fl_chart` (consultar la API de la versión instalada con Context7): puntos de peso diario y línea de media semanal (solo en los puntos con `averageKg != null`, sin unir los huecos), selector de periodo 30 días / 90 días / Todo (`SegmentedButton`), colores con contraste AA en claro y oscuro, y **alternativa textual siempre visible**: resumen (peso actual, media semanal, variación en el periodo) más la lista de registros de US1. Envolver el gráfico en `Semantics(label: ...)` con ese mismo resumen y excluir el lienzo del árbol semántico. Con menos de 2 registros mostrar «Necesitas al menos 2 registros…» en lugar del gráfico (US2.4)
- [X] T041 [US2] (depende de T040) Integrar `WeightChart` en `app/lib/features/weight/weight_screen.dart` encima de la lista, cargando `weightChart(period, utcOffsetMin)` con el periodo por defecto de 30 días y refrescando al guardar, editar o borrar un peso (US1.4)
- [X] T042 [P] [US2] Crear `app/test/weight/weight_chart_test.dart`: cambiar de periodo vuelve a pedir la gráfica con el `period` correcto; con menos de 2 registros se ve el mensaje y no el gráfico; el resumen textual (peso actual, media semanal, variación) está presente y tiene `Semantics`; la lista de registros acompaña al gráfico; el tamaño de texto grande no desborda

**Checkpoint**: US2 completa: gráfica con tres periodos y alternativa accesible (V2 de `quickstart.md`).

---

## Phase 6: Polish & cross-cutting

- [X] T043 [P] Comprobar `backend/tests/privacy/test_all_routes_require_identity.py`: verificación final: el conjunto contiene las 8 rutas nuevas (añadidas en T021, T032 y T039) y la lista de rutas públicas sigue siendo solo `/v1/health` y `/descargar/mykcal.apk`; revisar además que `test_consent_gate.py` y `test_disabled_account.py` cubren las rutas de peso y de propuesta
- [X] T044 [P] Auditoría de accesibilidad de la pantalla de peso y del diálogo de propuesta en `app/test/weight/weight_a11y_test.dart` (mismo patrón que `app/test/diary/diary_a11y_test.dart`): todos los controles con etiqueta, objetivos táctiles ≥ 48 dp, texto al 200% sin desbordes y contraste AA en claro y oscuro (FR-011, principio VIII)
- [X] T045 Actualizar `specs/007-peso-y-recalculo/research.md` R5 con las decisiones tomadas al implementar (la fila `pending` se borra si deja de cumplirse el umbral; una propuesta ignorada el día D queda bloqueada mientras `hoy < D + 7 días`)
- [X] T046 Pasar toda la batería: `cd backend && uv run ruff check && uv run ruff format --check && uv run pytest` y `cd app && flutter analyze && flutter test`, todo en verde
- [ ] T047 Ejecutar los escenarios V1–V3 de `specs/007-peso-y-recalculo/quickstart.md` contra un backend local con `alembic upgrade head` hasta `0007` y anotar el resultado (**pendiente**: los casos de V1–V3 —incluidos 78.2/78.6, 1 registro de 76 kg, aceptar, ignorar, objetivo manual y reabrir— están cubiertos por pruebas automáticas de integración, pero no se ha hecho la pasada manual en móvil/servidor real); V4 (APK desplegado desde `main`, principio IX) queda para después de fusionar

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Setup; **bloquea** todas las historias. Dentro de ella: T003 → T004; T005 → T006 → T007 → T012; T008, T009, T010, T011, T013, T015 en paralelo; T014 tras T013.
- **US1 (Phase 3)**, **US3 (Phase 4)** y **US2 (Phase 5)**: dependen solo de la Phase 2. Comparten `weight/service.py`, `weight/router.py` y `weight_screen.dart`, por lo que las tareas que tocan esos archivos se hacen en orden, no a la vez.
- **Polish (Phase 6)**: tras las historias deseadas.

### User Story Dependencies

- **US1 (P1)**: tras la Phase 2. Es el MVP; no depende de otra historia.
- **US3 (P1)**: tras la Phase 2. Sus tests crean los registros con `make_weight`, así que no necesita US1 para probarse; T031 conecta la reevaluación con el CRUD de US1 (requiere T020).
- **US2 (P2)**: tras la Phase 2. Reutiliza `moving_average_series` (T004); T041 integra la gráfica en la pantalla de US1 (requiere T023).

### Within Each User Story

- Tests primero y fallando → servicio → router → app → pruebas de app.

### Parallel Opportunities

- Phase 2: T003, T005, T008, T009, T010, T011, T013, T015 son archivos distintos.
- US1: T016–T019 en paralelo; T022 en paralelo con el backend.
- US3: T026–T028 en paralelo; T033 en paralelo con el backend.
- US2: T037–T038 en paralelo; T040 en paralelo con T039.

---

## Parallel Example: User Story 1

```text
# Tests de backend de US1 a la vez:
Task: "T016 test_weight_entries.py"
Task: "T017 test_weight_contract.py"
Task: "T018 test_user_isolation_weight.py"
Task: "T019 test_logs_no_secrets.py (peso)"

# Backend y controlador de la app a la vez (archivos distintos):
Task: "T020/T021 weight/service.py + router.py"
Task: "T022 weight_controller.dart"
```

---

## Implementation Strategy

### MVP First (US1)

1. Phase 1 y Phase 2 (incluida la media/umbral puros, aunque US1 aún no los use: son la base de US2 y US3 y se prueban sin base de datos).
2. Phase 3 (US1): registrar, corregir y borrar pesos.
3. **PARAR y validar** V1 de `quickstart.md`.

### Incremental Delivery

1. + US3 → propuesta de recálculo (V3): es lo que cierra el valor de la épica E9.
2. + US2 → gráfica (V2).
3. Cada historia deja la app usable (principio IX); fusionar a `dev` cuando pasen las pruebas y a `main` tras la comprobación en el móvil.

---

## Notes

- `weight_entry` y `WeightEntry` ya existen desde 002 (`profile/models.py`); no se vuelven a crear ni se mueven (R1).
- `PUT /v1/profile` (002) ya guarda un peso y puede recalcular el objetivo de forma automática si cambia el peso; esa vía no se toca. La propuesta de 007 se reevalúa de forma perezosa en cada `GET /v1/recalc-proposal` (T029 actualiza `target_from_id` y `reference_weight_kg` de la fila `pending`), de modo que un cambio de objetivo por esa vía no deja una propuesta obsoleta.
- Ningún log debe incluir pesos ni fechas de registros (principio X; T019).
- Hacer commit tras cada tarea o grupo lógico; nada de commits directos a `main`.
