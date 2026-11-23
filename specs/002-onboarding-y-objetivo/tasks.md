# Tasks: Onboarding, objetivo diario y baja

**Input**: Design documents from `specs/002-onboarding-y-objetivo/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R17), data-model.md, contracts/ (`api-changes.md`, `calc-cases.md`, `ui-flows.md`), quickstart.md

**Tests**: se incluyen. Se sigue la práctica de la 001 y la 008 (test primero) y el principio VI. Los tests de cada historia se escriben antes y deben fallar.

**Organization**: por historia de usuario. El cimiento común (cálculo, tablas, errores, puerta de consentimiento, modelos de la app) está en la Phase 2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de `spec.md` (US1–US4)
- Rutas de backend relativas a `backend/src/mykcal/` salvo que se indique `tests/`; las de la app, a `app/`.

---

## Phase 1: Setup

- [X] T001 Comprobar que la rama es `002-onboarding-y-objetivo` y que `cd backend && uv run pytest` y `cd app && flutter test` pasan antes de empezar (línea base de la 001 y la 008)

---

## Phase 2: Foundational (bloquea todas las historias)

### Cálculo puro (R1–R3)

- [X] T002 [P] Test unitario `backend/tests/unit/test_target_calc.py`: parametrizar con las 13 filas de `specs/002-onboarding-y-objetivo/contracts/calc-cases.md` (gasto, kcal, proteína, grasa, carbohidratos, hierro y avisos) y la tabla de fibra y micros por sexo de FR-011; más una rejilla (edades 18/50/51/100, alturas 100/250, pesos 30/300, ambos sexos, 5 niveles y 3 objetivos) que verifique: mismo `CalcInputs` → mismo `CalcResult`, `kcal ≥ mínimo(sexo)` (1.500 hombre / 1.200 mujer), `carbs_g ≥ 0` y ningún valor negativo
- [X] T003 Crear `backend/src/mykcal/targets/__init__.py` y `backend/src/mykcal/targets/calc.py` con `CalcInputs`, `CalcResult` y `calculate()` pura, sin E/S ni reloj ni `float`. Reglas (data-model.md «CalcInputs → CalcResult»): `bmr = 10·peso + 6,25·altura − 5·edad + (5 hombre / −161 mujer)`; `tdee = bmr · factor` con factores sedentary 1,2 / light 1,375 / moderate 1,55 / high 1,725 / very_high 1,9; `kcal = tdee · (0,80 lose_fat / 1,00 maintain / 1,10 gain_muscle)` con mínimo 1.500 (male) o 1.200 (female) aplicado **antes** de grasa y carbohidratos y aviso `MIN_KCAL_APPLIED`; proteína = 2,2 / 1,8 / 2,0 g/kg × peso; grasa = `0,25·kcal/9`; `carbs = (kcal − 4·proteína − 9·grasa)/4`, si es negativo `0` y aviso `CARBS_CLAMPED`; fibra y micros por sexo de FR-011 (hierro mujer 8 mg si `edad ≥ 51`, 18 mg si no); todo con `decimal.Decimal`, intermedios sin redondear y `ROUND_HALF_UP` a la unidad solo al final (R2). Hace pasar T002

### Base de datos

- [X] T004 Crear `backend/alembic/versions/0002_onboarding.py` (`revision = "0002_onboarding"`, `down_revision = "0001_access"`, con `downgrade`) con las cuatro tablas de `data-model.md`, constraints verbatim:
  - `health_consent`: `id uuid PK default gen_random_uuid()`, `user_id uuid NOT NULL FK user_account.id`, `text_version text NOT NULL` (1–32 caracteres, CHECK), `accepted_at timestamptz NOT NULL`, `UNIQUE (user_id, text_version)`
  - `user_profile`: `user_id uuid PK FK user_account.id`, `age smallint NOT NULL CHECK (age BETWEEN 18 AND 100)`, `sex text NOT NULL CHECK (sex IN ('male','female'))`, `height_cm smallint NOT NULL CHECK (height_cm BETWEEN 100 AND 250)`, `activity_level text NOT NULL CHECK IN ('sedentary','light','moderate','high','very_high')`, `goal text NOT NULL CHECK IN ('lose_fat','maintain','gain_muscle')`, `created_at`, `updated_at` `timestamptz NOT NULL`
  - `weight_entry`: `id uuid PK`, `user_id uuid NOT NULL FK`, `measured_on date NOT NULL`, `weight_kg numeric(4,1) NOT NULL CHECK (weight_kg BETWEEN 30 AND 300)`, `created_at`, `updated_at`, `UNIQUE (user_id, measured_on)`
  - `daily_target`: `id uuid PK`, `user_id uuid NOT NULL FK`, `is_current boolean NOT NULL`, índice único parcial `(user_id) WHERE is_current`, `effective_from timestamptz NOT NULL`, `superseded_at timestamptz NULL` con CHECK `(is_current) = (superseded_at IS NULL)`, `source text NOT NULL CHECK IN ('calculated','manual')`, enteros NOT NULL con rangos kcal 1–10.000, protein_g 0–1.000, carbs_g 0–2.000, fat_g 0–1.000, fiber_g 0–200, sodium_mg 0–20.000, potassium_mg 0–20.000, calcium_mg 0–10.000, iron_mg 0–200, magnesium_mg 0–5.000, vitamin_d_ug 0–500, vitamin_c_mg 0–5.000; `calc_weight_kg numeric(4,1) NOT NULL`, `calc_age smallint`, `calc_sex text`, `calc_height_cm smallint`, `calc_activity text`, `calc_goal text` (todos NOT NULL), `calculated_at timestamptz NOT NULL`, `calc_notices text[] NOT NULL default '{}'`; índice `ix_daily_target_user_effective (user_id, effective_from)`
- [X] T005 [P] Crear `backend/src/mykcal/consent/__init__.py` y `consent/models.py` con `HealthConsent` (SQLAlchemy 2, mismo estilo que `accounts/models.py`) según T004
- [X] T006 [P] Crear `backend/src/mykcal/profile/__init__.py` y `profile/models.py` con `UserProfile` y `WeightEntry` según T004
- [X] T007 [P] Crear `backend/src/mykcal/targets/models.py` con `DailyTarget` según T004
- [X] T008 Registrar los modelos nuevos donde `alembic/env.py` y `tests/conftest.py` cargan el metadata, y añadir a `tests/integration/test_migrate.py` una comprobación de que `0002_onboarding` sube y baja y de los CHECK (edad 17, altura 99, peso 29,9, dos `is_current` del mismo usuario → error)

### Errores, consentimiento y servicio de versiones

- [X] T009 En `backend/src/mykcal/core/errors.py` añadir a `ErrorCode`: `CONSENT_REQUIRED`, `CONSENT_VERSION_MISMATCH`, `PROFILE_NOT_FOUND`, `PROFILE_REQUIRED`, `TARGET_NOT_FOUND`; y a `ErrorBody` el campo opcional `fields: list[str] | None` (solo con `VALIDATION_ERROR`; nombres de campo, nunca valores; R14). En `main.py`, el manejador de `RequestValidationError` rellena `fields` con los nombres de los campos inválidos de `exc.errors()` sin copiar `input`
- [X] T010 En `backend/src/mykcal/core/auth.py` añadir `require_consent` encadenada tras `require_active_account`: `403 CONSENT_REQUIRED` («Debes aceptar el tratamiento de tus datos de salud.») si el usuario no tiene ninguna fila en `health_consent` (R9). Test en `backend/tests/integration/test_auth_core.py`
- [X] T011 Crear `backend/src/mykcal/targets/service.py` con `save_version(session, user_id, values, source, calc_data, notices, now)`: en la misma transacción pone `is_current=false` y `superseded_at=now` en la vigente e inserta la nueva con `is_current=true` y `effective_from=now` (R4); `current_target(session, user_id)`; y `values_from_result(CalcResult)`. Sin commit propio (lo hace quien llama)
- [X] T012 [P] Crear `backend/src/mykcal/targets/schemas.py` con `TargetValues` (12 enteros con los rangos de T004, `extra="forbid"`), `DailyTarget` (`values`, `source`, `effective_from`, `calculation{weight_kg, age, sex, height_cm, activity_level, goal, calculated_at, notices}`) y los enums `Sex`, `ActivityLevel`, `Goal`, según `contracts/api-changes.md`

### Contrato y app (base común)

- [X] T013 Actualizar `specs/001-acceso-y-despliegue/contracts/openapi.yaml` con el «Fragmento OpenAPI» de `contracts/api-changes.md` (7 rutas, schemas nuevos, `Me.onboarding` en `required` y `properties`, nuevos códigos y `fields` en `ErrorBody`, `info.version: 0.2.0`)
- [X] T014 [P] Crear `app/lib/core/format/numbers.dart` con formateadores `formatInt(int)` (`2.759`) y `formatWeight(double)` (`78,4`) sobre `intl` con locale `es`, y `parseDecimal(String)` que acepta coma o punto (R17). Test en `app/test/format/numbers_test.dart`
- [X] T015 [P] En `app/lib/core/api/models.dart` añadir `Onboarding` (enum `consent|profile|done`), el campo `Me.onboarding`, y los modelos `Profile`, `ProfileInput`, `ProfileSaved` (con `Recalculation{status, previous, proposed}`), `TargetValues` y `DailyTarget` con `fromJson`/`toJson` según `contracts/api-changes.md`
- [X] T016 En `app/lib/core/api/mykcal_api.dart` añadir a `MykcalApi` y a `HttpMykcalApi`: `acceptConsent(String version)`, `profile()`, `saveProfile(ProfileInput)`, `target()`, `saveTarget(TargetValues)`, `recalculateTarget()` y `deactivate()`. Actualizar los fakes de `app/test/helpers/fakes.dart`. Test de cliente en `app/test/api/api_client_test.dart` para el mapeo de `CONSENT_REQUIRED`, `VALIDATION_ERROR` con `fields` y el `204` de la baja (depende de T015)

**Checkpoint**: T002 en verde; `alembic upgrade head` y `downgrade -1` funcionan.

---

## Phase 3: User Story 1 - Consentimiento y perfil (Priority: P1) 🎯 MVP

**Goal**: tras registrarse, el usuario acepta el consentimiento y completa el perfil; queda guardado con el peso y el primer objetivo.

**Independent Test**: escenarios 1–6 de `quickstart.md`.

### Tests for User Story 1 ⚠️ (escribir primero y comprobar que fallan)

- [X] T017 [P] [US1] `backend/tests/integration/test_consent.py`: `POST /v1/consent` con la versión vigente → `201` con `text_version` y `accepted_at` (hora del servidor, FR-003); repetirlo no crea otra fila (idempotente); versión desconocida → `409 CONSENT_VERSION_MISMATCH`; sin cuenta → `403 ACCOUNT_NOT_REGISTERED`; desactivada → `403 ACCOUNT_DISABLED`
- [X] T018 [P] [US1] `backend/tests/integration/test_onboarding.py`: `GET /v1/me` devuelve `onboarding: consent` sin consentimiento, `profile` con consentimiento y sin perfil, y `done` tras guardar el perfil; `PUT /v1/profile` por primera vez crea en una sola transacción perfil + `weight_entry` de `measured_on` + `daily_target` `calculated` (el ejemplo de US2.2: hombre 30, 180, 80, moderate, maintain → 2759/144/373/77) y responde `recalculation.status = created`; el peso queda igual a `calc_weight_kg` (FR-006); si falla el cálculo no queda ni perfil ni peso (rollback); `GET /v1/profile` devuelve el peso del registro más reciente; fuera de rango (edad 17, altura 30, peso 29,9 o 300,1, peso con 2 decimales) → `400 VALIDATION_ERROR` con `fields` y sin escribir nada; se aceptan 30, 80.3, 99.9 y 300 y se rechazan 80.25 y 300.1; `measured_on` más de 1 día posterior a la fecha UTC del servidor → `400`
- [X] T019 [P] [US1] `backend/tests/contract/test_onboarding_contract.py`: respuestas de `/v1/consent`, `/v1/profile` (GET y PUT) y `/v1/me` validadas contra `openapi.yaml` con el helper de `tests/contract/schema.py`
- [X] T020 [P] [US1] `backend/tests/privacy/test_consent_gate.py` (marker `privacy`, SC-003): lista cerrada `HEALTH_DATA_ROUTES = {GET/PUT /v1/profile, GET/PUT /v1/target, POST /v1/target/recalculate}`; cada una responde `403 CONSENT_REQUIRED` sin consentimiento y no escribe ninguna fila (comprobar el conteo de `user_profile`, `weight_entry` y `daily_target`); otra prueba verifica que toda ruta del app está en `HEALTH_DATA_ROUTES` o en `NO_CONSENT_NEEDED = {GET /v1/me, POST /v1/registration, POST /v1/consent, POST /v1/me/deactivation, /v1/admin/*, /v1/health, /descargar/mykcal.apk}` (una ruta nueva sin clasificar falla). Ampliar `test_all_routes_require_identity.py` con las 7 rutas nuevas
- [X] T021 [P] [US1] `backend/tests/privacy/test_user_isolation_health.py` (marker `isolation`): con dos usuarios con perfil, objetivo y peso, `GET /v1/profile` y `GET /v1/target` de cada uno devuelven solo lo suyo y `PUT /v1/profile` de A no cambia nada de B
- [X] T022 [P] [US1] Ampliar `backend/tests/privacy/test_logs_no_secrets.py`: tras un `PUT /v1/profile` y un `PUT /v1/target`, los logs no contienen ni edad, altura, peso, sexo ni valores del objetivo; solo eventos `consent_recorded`, `profile_saved`, `target_saved` (con `source`) y el `user_id` interno (principio X)
- [X] T023 [P] [US1] `app/test/consent/consent_screen_test.dart`: sin casilla el botón «Aceptar y continuar» está deshabilitado y las únicas salidas son «Cerrar sesión» y «Darme de baja», que abre el mismo diálogo de confirmación de la baja y, al confirmar, llama a `deactivate` (US1.2); con casilla llama a `acceptConsent` con la versión de `consentTextVersion`; sin conexión muestra «Sin conexión. Inténtalo de nuevo.» y la casilla sigue marcada; `CONSENT_VERSION_MISMATCH` → «Actualiza la app para continuar.»; guías de accesibilidad de `test/helpers/a11y.dart`
- [X] T024 [P] [US1] `app/test/profile/profile_screen_test.dart`: errores junto al campo («Entre 18 y 100 años», «Entre 100 y 250 cm», «Entre 30 y 300 kg, con un decimal como máximo», «Obligatorio») sin llamar a la API (US1.5); el peso acepta `80,5` y `80.5` y se envía `80.5`; error de red conserva lo escrito; `VALIDATION_ERROR` con `fields` marca esos campos; el borrador sobrevive a una reconstrucción de la pantalla; guías de accesibilidad con texto al 200%
- [X] T025 [P] [US1] Ampliar `app/test/auth/bootstrap_test.dart` o crear `app/test/app_gate_test.dart`: `Active` con `onboarding` `consent` → pantalla de consentimiento, `profile` → perfil, `done` → inicio

### Implementation for User Story 1

- [X] T026 [P] [US1] Crear `backend/src/mykcal/consent/service.py` con `CURRENT_CONSENT_VERSION = "2026-11-1"` y `accept(session, user_id, version, now)`: `409 CONSENT_VERSION_MISMATCH` si no coincide; `INSERT … ON CONFLICT (user_id, text_version) DO NOTHING`; devuelve la fila. Y `has_consent(session, user_id)`. Registra `consent_recorded` con el `user_id` interno (R8)
- [X] T027 [US1] Crear `backend/src/mykcal/consent/router.py` con `POST /v1/consent` (201, `Consent{text_version, accepted_at}`) tras `require_active_account` (no `require_consent`) y registrarlo en `main.py` (depende de T026)
- [X] T028 [P] [US1] Crear `backend/src/mykcal/profile/schemas.py`: `ProfileInput` (`age` 18–100, `sex`, `height_cm` 100–250, `weight_kg: condecimal(ge=30, le=300, max_digits=4, decimal_places=1)` (Pydantic), nunca `float`, guardado como `Decimal` en `numeric(4,1)` y pasado como `Decimal` a `CalcInputs`, `activity_level`, `goal`, `measured_on: date`; `extra="forbid"`), `Profile` y `ProfileSaved` según `contracts/api-changes.md`
- [X] T029 [US1] Crear `backend/src/mykcal/profile/service.py` con `save_profile(session, user_id, data, now)` en una transacción (R11): upsert de `user_profile`, upsert de `weight_entry` con `ON CONFLICT (user_id, measured_on) DO UPDATE` (R6), y, si no hay objetivo vigente, `calculate()` + `targets.service.save_version(source="calculated")` con los `calc_*` y `calc_notices`; devuelve `recalculation.status = created`. Rechaza `measured_on` > fecha UTC + 1 día. Registra `profile_saved`. Y `get_profile` con el peso del registro más reciente (depende de T011, T028)
- [X] T030 [US1] Crear `backend/src/mykcal/profile/router.py` con `GET /v1/profile` (`404 PROFILE_NOT_FOUND`) y `PUT /v1/profile`, ambos tras `require_consent`, y registrarlo en `main.py` (depende de T010, T029)
- [X] T031 [US1] En `backend/src/mykcal/accounts/schemas.py` y `accounts/router.py`, añadir `Me.onboarding` calculado por petición (R10): `consent` sin fila en `health_consent`; `profile` con consentimiento y sin `user_profile` o sin `daily_target` vigente; `done` en otro caso. También en la respuesta de `POST /v1/registration` (depende de T026)
- [X] T032 [P] [US1] Añadir a `app/lib/l10n/app_es.arb` y regenerar (`flutter gen-l10n`) las claves de las pantallas 1 y 2 de `contracts/ui-flows.md`: consentimiento (título, **texto provisional que empieza por «BORRADOR —», redacción pendiente de Erick (T073)**, casilla, botones, errores), `consentTextVersion` = `2026-11-1`, perfil (campos, sufijos, ayuda del sexo, los 5 niveles de actividad con su descripción de FR-005, los 3 objetivos, errores de rango, «Calcular mi objetivo», «Guardar»)
- [X] T033 [US1] Crear `app/lib/features/consent/consent_screen.dart` según la pantalla 1 de `ui-flows.md`; al aceptar llama a `acceptConsent` y refresca `Me` a través de `AuthController` (método nuevo `refreshAccount()` que recarga `/v1/me`). El botón «Darme de baja» reutiliza `confirmDeactivation` de `app/lib/features/settings/deactivate_dialog.dart` (T066) (depende de T016, T032)
- [X] T034 [P] [US1] Crear `app/lib/features/profile/profile_controller.dart` con el borrador en memoria (`ProfileDraftNotifier`) y la validación de rangos de FR-004 (funciones puras)
- [X] T035 [US1] Crear `app/lib/features/profile/profile_screen.dart` (modo onboarding y modo edición, pantalla 2 de `ui-flows.md`): `SegmentedButton` de sexo con la ayuda «Solo se usa para el cálculo», lista de 5 niveles, 3 `RadioListTile`, errores junto al campo anunciados al lector; `measured_on` = fecha local del móvil. En onboarding, tras `created` navega al resultado del objetivo (US2) (depende de T034)
- [X] T036 [US1] En `app/lib/app.dart`, hacer que `AppGate` mire `me.onboarding` para `Active`: `consent` → `ConsentScreen`, `profile` → `ProfileScreen` (onboarding), `done` → `HomeScreen` (R16). Hace pasar T025

**Checkpoint**: T017–T025 en verde; escenarios 1–6 del quickstart.

---

## Phase 4: User Story 2 - Ver el objetivo diario calculado (Priority: P1)

**Goal**: al terminar el perfil se ve el objetivo (kcal, macros, fibra y 7 micros) y, al cambiar el perfil, se recalcula o se propone.

**Independent Test**: escenarios 7–9, 12 y 14 de `quickstart.md`.

### Tests for User Story 2 ⚠️

- [X] T037 [P] [US2] `backend/tests/integration/test_recalculation.py`: con objetivo `calculated`, `PUT /v1/profile` cambiando la actividad o el objetivo → nueva versión (la anterior `is_current=false` con `superseded_at`, un solo vigente por usuario), `recalculation.status = applied` con `previous`; el mismo perfil sin cambios → `none` y sin filas nuevas; cambiar solo el peso en el perfil cuenta como cambio del cálculo; `POST /v1/target/recalculate` guarda una versión `calculated` con el perfil y el peso actuales; sin perfil → `409 PROFILE_REQUIRED`; `GET /v1/target` → `404 TARGET_NOT_FOUND` sin objetivo; con un registro de peso posterior al cálculo (insertado directamente en `weight_entry`), un `PUT /v1/profile` que reenvía ese mismo peso y solo cambia la altura recalcula con ese peso, y un `PUT` sin cambios con ese mismo peso → `none` (R12); el ejemplo de US2.3 (perder grasa → 2207/176/238/61)
- [X] T038 [P] [US2] `backend/tests/contract/test_onboarding_contract.py` (ampliar): `GET /v1/target`, `POST /v1/target/recalculate` y `PUT /v1/profile` con `applied`/`proposed` contra `openapi.yaml`
- [X] T039 [P] [US2] `app/test/target/target_screen_test.dart`: modo resultado muestra kcal con formato `2.759`, proteína/carbohidratos/grasa, fibra y los 7 micros con «mínimo»/«máximo» como texto, botón «Empezar» que refresca `Me`; avisos `MIN_KCAL_APPLIED` y `CARBS_CLAMPED` con icono y texto; modo detalle con «Editar»; guías de accesibilidad
- [X] T040 [P] [US2] `app/test/home/home_target_card_test.dart`: la tarjeta «Tu objetivo de hoy» muestra kcal y macros leídos de `GET /v1/target`, «Ver detalle» abre el detalle, y un fallo muestra el error de conexión con «Reintentar»
- [X] T041 [P] [US2] Ampliar `app/test/profile/profile_screen_test.dart`: en edición, `applied` muestra el diálogo «Tu objetivo se ha actualizado» con antes → después; `none` muestra «Perfil guardado» y vuelve atrás

### Implementation for User Story 2

- [X] T042 [US2] Ampliar `backend/src/mykcal/targets/service.py` con `recalculate(session, user_id, now, weight_kg=None)` (perfil + el peso dado o, si no, el último registro → `calculate()` → `save_version(source="calculated")`) y `needs_recalc(current, submitted, previous_weight)`: `True` si alguno de edad, sexo, altura, actividad u objetivo enviados difiere de los `calc_*` vigentes, o si `submitted.weight_kg != previous_weight` (último registro **antes** de guardar) (R12). Ampliar `profile/service.save_profile`: tras guardar un perfil existente, si el objetivo vigente es `calculated` y `needs_recalc` → recalcula y devuelve `applied` con `previous`; si no hay cambios → `none` (la rama `manual` se añade en US3)
- [X] T043 [US2] Crear `backend/src/mykcal/targets/router.py` con `GET /v1/target` (`404 TARGET_NOT_FOUND`) y `POST /v1/target/recalculate` (`409 PROFILE_REQUIRED`), ambos tras `require_consent`, y registrarlo en `main.py`. Registra `target_saved` con `source`
- [X] T044 [P] [US2] Añadir a `app/lib/l10n/app_es.arb` las claves de la pantalla 3 y del diálogo de recálculo: «Tu objetivo diario», nombres y unidades de macros y micros, «mínimo»/«máximo», los dos avisos, «Empezar», «Ver detalle», «Tu objetivo de hoy», «Tu objetivo se ha actualizado», «Perfil guardado». Regenerar
- [X] T045 [US2] Crear `app/lib/features/target/target_controller.dart` (`FutureProvider` sobre `MykcalApi.target()` con invalidación tras guardar) y `app/lib/features/target/target_screen.dart` (modo resultado y modo detalle, pantalla 3 de `ui-flows.md`)
- [X] T046 [US2] En `app/lib/features/profile/profile_screen.dart`, tras el guardado en edición: `applied` → diálogo con antes → después; `none` → `SnackBar` y volver; y en onboarding `created` → `TargetScreen` en modo resultado (depende de T045)
- [X] T047 [US2] En `app/lib/features/home/home_screen.dart`, sustituir el texto provisional `homePlaceholder` por la tarjeta «Tu objetivo de hoy» con «Ver detalle» (pantalla 5 de `ui-flows.md`) y actualizar `app/test/home/home_menu_test.dart` si depende del texto retirado

**Checkpoint**: T037–T041 en verde; escenarios 7–9, 12 y 14.

---

## Phase 5: User Story 3 - Editar el objetivo a mano (Priority: P2)

**Goal**: el usuario sobrescribe valores; un objetivo manual no se recalcula sin su confirmación y se puede volver al cálculo.

**Independent Test**: escenarios 10, 11 y 13 de `quickstart.md`.

### Tests for User Story 3 ⚠️

- [X] T048 [P] [US3] `backend/tests/integration/test_manual_target.py`: `PUT /v1/target` con los 12 valores guarda una versión `manual` que copia `calc_*`, `calculated_at` y `calc_notices` de la anterior (FR-013); valor negativo, no entero, ausente o fuera de rango (kcal 0 o 10.001) → `400 VALIDATION_ERROR` con `fields`; sin perfil → `409 PROFILE_REQUIRED`; guardar dos veces deja un solo vigente
- [X] T049 [P] [US3] Ampliar `backend/tests/integration/test_recalculation.py` (SC-004): con objetivo `manual`, `PUT /v1/profile` con cambios devuelve `recalculation.status = proposed` con `proposed` y **no escribe ninguna fila ni cambia el vigente**; `POST /v1/target/recalculate` lo devuelve a `calculated` con los datos actuales (US3.3); sin cambios → `none`
- [X] T050 [P] [US3] `app/test/target/macro_check_test.dart`: función pura `macroEnergyMismatch(kcal, protein, carbs, fat)` → `true` si `|4P + 4C + 9G − kcal| / kcal > 0,05`; casos: exacto, justo en 5% (no avisa), 5,1% (avisa), kcal 0 (sin dividir)
- [X] T051 [P] [US3] `app/test/target/target_edit_screen_test.dart`: 12 campos enteros con unidad; el aviso de macros aparece en vivo y no deshabilita «Guardar» (FR-017, US3.4); vacío, negativo o decimal → «Escribe un número entero de 0 o más» (kcal: «de 1 o más»); «Guardar» llama a `saveTarget` con los 12 valores; sin conexión conserva lo escrito; guías de accesibilidad
- [X] T052 [P] [US3] Ampliar `app/test/target/target_screen_test.dart` y `app/test/profile/profile_screen_test.dart`: «Editado a mano» solo con `source = manual`; «Volver al cálculo» pide confirmación y llama a `recalculateTarget`; con `proposed` el diálogo «Tu objetivo está editado a mano…» muestra actual → propuesto, «Mantener el mío» no llama a nada y «Recalcular» llama a `recalculateTarget`

### Implementation for User Story 3

- [X] T053 [US3] Añadir `PUT /v1/target` en `backend/src/mykcal/targets/router.py` (tras `require_consent`, `TargetValues` como cuerpo) y `save_manual(session, user_id, values, now)` en `targets/service.py`: `409 PROFILE_REQUIRED` si no hay objetivo vigente; guarda `source="manual"` copiando los `calc_*` de la vigente
- [X] T054 [US3] En `profile/service.save_profile`, rama `manual`: si el objetivo vigente es `manual` y `needs_recalc`, calcular el objetivo que saldría **sin guardarlo** y devolver `recalculation.status = proposed` con `proposed`; el perfil y el peso sí se guardan (R12, FR-015)
- [X] T055 [P] [US3] Crear `app/lib/features/target/macro_check.dart` con `macroEnergyMismatch` (R13). Hace pasar T050
- [X] T056 [P] [US3] Añadir a `app/lib/l10n/app_es.arb` las claves de la pantalla 4 y del diálogo `proposed`: «Editado a mano», «Editar», «Volver al cálculo» y su confirmación, aviso de macros con los dos totales, errores de enteros, «Objetivo guardado», «Mantener el mío», «Recalcular». Regenerar
- [X] T057 [US3] Crear `app/lib/features/target/target_edit_screen.dart` (pantalla 4 de `ui-flows.md`) con borrador `TargetEditNotifier` en memoria y aviso en vivo; guardar → `saveTarget` → invalidar `targetProvider` y volver
- [X] T058 [US3] En `app/lib/features/target/target_screen.dart`, mostrar «Editado a mano» y los botones «Editar» y «Volver al cálculo» (este último solo si `manual`, con confirmación). En `profile_screen.dart`, tratar `proposed` con el diálogo «Mantener el mío» / «Recalcular» (depende de T057)

**Checkpoint**: T048–T052 en verde; escenarios 10, 11 y 13.

---

## Phase 6: User Story 4 - Darse de baja (Priority: P3)

**Goal**: el usuario se da de baja desde ajustes; la cuenta queda desactivada, se cierra la sesión y no puede volver a operar.

**Independent Test**: escenarios 17–20 de `quickstart.md`.

### Tests for User Story 4 ⚠️

- [X] T059 [P] [US4] `backend/tests/integration/test_deactivation.py`: `POST /v1/me/deactivation` → `204`, `status='disabled'` y `disabled_at` rellenado; los datos (perfil, pesos, objetivos) se conservan (FR-019); el mismo token ya no pasa: `403 ACCOUNT_DISABLED` en las rutas de datos; `GET /v1/me` devuelve `status: disabled`; una segunda baja → `403 ACCOUNT_DISABLED`; la plaza se libera (`count_active` baja en 1 y un alta nueva con 50 cuentas activas menos una tiene éxito); usa el bloqueo de `REGISTRATION_LOCK_KEY` (no se cruza con un alta concurrente, patrón de `test_registration_concurrency.py`); se registra `account_deactivated` con `user_id` y sin `sub`
- [X] T060 [P] [US4] Ampliar `backend/tests/privacy/test_disabled_account.py` (SC-005): las 7 rutas nuevas rechazan una cuenta desactivada con `ACCOUNT_DISABLED`, incluidas `POST /v1/consent` y `POST /v1/me/deactivation`
- [X] T061 [P] [US4] `app/test/settings/settings_screen_test.dart`: lista «Mi perfil», «Mi objetivo» y «Darse de baja» en color de error y separada; el diálogo muestra el texto de `ui-flows.md` (cuenta desactivada, sin volver a entrar, datos conservados) con «Cancelar» y «Darme de baja»; «Cancelar» no llama a nada; confirmar llama a `deactivate` y luego a `signOut`; error de red → `SnackBar` y la cuenta sigue activa; el aviso «Tu cuenta se ha dado de baja.» aparece en `AccessScreen`
- [X] T062 [P] [US4] Ampliar `app/test/home/home_menu_test.dart`: el menú ⋮ incluye «Ajustes» para todos entre «Compartir Mykcal» y «Cerrar sesión»

### Implementation for User Story 4

- [X] T063 [US4] En `backend/src/mykcal/accounts/service.py` añadir `deactivate(sessionmaker, account_id)`: dentro de `session.begin()` toma `lock_registration`, pone `status='disabled'` y `disabled_at=now()` y registra `account_deactivated` (R15). En `accounts/router.py`, `POST /v1/me/deactivation` → `204` tras `require_active_account` (no `require_consent`)
- [X] T064 [P] [US4] Añadir a `app/lib/l10n/app_es.arb` las claves de las pantallas 6 y 7 («Ajustes», «Mi perfil», «Mi objetivo», «Darse de baja», diálogo, «Tu cuenta se ha dado de baja.») y regenerar
- [X] T065 [US4] En `app/lib/core/auth/auth_controller.dart`, añadir `deactivate()` (llama a `MykcalApi.deactivate()` y, si va bien, `signOut()` y estado `SignedOut(notice: AccessNotice.accountDeactivated)`); en `app/lib/features/access/access_screen.dart`, mostrar el aviso nuevo (depende de T064)
- [X] T066 [US4] Crear `app/lib/features/settings/deactivate_dialog.dart` con `Future<void> confirmDeactivation(BuildContext, WidgetRef)` (diálogo de la pantalla 7, usado desde Ajustes y desde Consentimiento) y `app/lib/features/settings/settings_screen.dart` (pantalla 6) que lo usa, y añadir en `home_screen.dart` la entrada «Ajustes» del menú que la abre

**Checkpoint**: T059–T062 en verde; escenarios 17–20.

---

## Phase 7: Polish y cierre

- [X] T067 [P] `cd backend && uv run ruff check && uv run pytest` (unit, integración, contrato y privacy) y corregir avisos
- [X] T068 [P] `cd app && flutter analyze && flutter test` y corregir avisos
- [ ] T069 [P] Actualizar `specs/001-acceso-y-despliegue/contracts/ui-flows.md` con un enlace a `specs/002-onboarding-y-objetivo/contracts/ui-flows.md` y la nota de que la pantalla de inicio ya no es provisional
- [ ] T070 [P] Actualizar `backend/.env.example`, `app/README.md` y `docs/deploy` si cambia algo (no se esperan variables nuevas; confirmar y anotar «sin cambios» si es así)
- [ ] T071 Desplegar la rama en Dokploy `dev` (la migración `0002_onboarding` se aplica en el arranque con `migrate.py`) y comprobar `GET /v1/health`
- [ ] T072 Compilar con `app/scripts/build_apk.sh dev`, instalar en el emulador y en el móvil con `adb install -r` y recorrer los escenarios 1–21 de `specs/002-onboarding-y-objetivo/quickstart.md` (incluidas las comprobaciones SQL de la sección 5), anotando el resultado en el PR; publicar el APK con `app/scripts/publish_apk.sh dev`
- [ ] T073 **Bloquea el merge de `dev` → `main`**: sustituir el texto provisional del consentimiento en `app/lib/l10n/app_es.arb` por el definitivo redactado por Erick. Si el texto cambia respecto al que vio algún usuario de `dev`, subir a la vez `CURRENT_CONSENT_VERSION` (backend) y `consentTextVersion` (app). Añadir una prueba en `app/test/consent/consent_screen_test.dart` que falle si el texto contiene la marca «BORRADOR»
- [ ] T074 Abrir el PR de `002-onboarding-y-objetivo` → `dev`; si T073 sigue pendiente, indicar en la descripción que bloquea la publicación en `main`

---

## Dependencies & Execution Order

- **Phase 1** → **Phase 2** → historias. La Phase 2 bloquea todo: T003 (cálculo), T004–T008 (tablas), T009–T012 (errores, consentimiento, versiones) y T013–T016 (contrato y app).
- **US1** (T017–T036) no depende de otras historias; deja el onboarding completo hasta crear el primer objetivo.
- **US2** (T037–T047) depende de US1 (necesita perfil y objetivo creados) y de T011.
- **US3** (T048–T058) depende de US2 (`target_screen`, `recalculate`, `needs_recalc`).
- **US4** (T059–T066) es independiente de US2 y US3: solo necesita la Phase 2 y las pantallas de inicio. Puede hacerse en paralelo con US2/US3 si hay dos personas.
- T033 usa el diálogo de T066. Si US4 aún no está hecha, T033 deja el botón «Darme de baja» detrás de un `TODO(T066)` y T066 lo conecta.
- **Phase 7** al final. T073 puede hacerse en cuanto Erick entregue el texto, y es obligatoria antes de `dev` → `main`.

Orden dentro de cada historia: tests (fallan) → modelos y servicio → rutas → app.

## Parallel Opportunities

- Phase 2: T005, T006, T007 y T012 en paralelo; T014 y T015 en paralelo con todo el backend; T002 antes de T003.
- US1: T017–T025 (tests, archivos distintos) en paralelo; después T026 ‖ T028 ‖ T032 ‖ T034.
- US2: T037–T041 en paralelo; T044 ‖ T042.
- US3: T048–T052 en paralelo; T055 ‖ T056.
- US4: T059–T062 en paralelo; T063 (backend) ‖ T064 (app).
- Backend y app avanzan en paralelo dentro de cada historia, porque el contrato (T013) y los fakes (T016) ya están fijados.

## Implementation Strategy

- **MVP = Phase 1 + 2 + US1 + US2**: el usuario nuevo acepta el consentimiento, completa el perfil, ve su objetivo y puede cambiar el perfil con recálculo automático. Es lo que desbloquea la 003 y la 004.
- **Incremento 2 = US3** (edición manual), **incremento 3 = US4** (baja). Las épicas P2 y P3 son las primeras en recortarse si el plazo aprieta (constitución), pero la baja es el único modo de liberar una plaza de las 50 desde la app, así que conviene no dejarla fuera de la primera entrega a los usuarios.
- Cerrar con T071–T074: despliegue en `dev`, APK y escenarios (principio IX).
