# Research: Peso y recálculo del objetivo (Phase 0)

No queda ningún `NEEDS CLARIFICATION`: la spec se aclaró en la sesión 2026-11-25. Este documento fija
las decisiones de diseño sobre el código ya existente de 002.

## R1 — Reutilizar `weight_entry` en vez de crear tabla nueva

**Decisión**: usar la tabla `weight_entry` ya creada en 002 (`backend/src/mykcal/profile/models.py`):
`(user_id, measured_on)` único, `weight_kg Numeric(4,1)` con check 30–300, `created_at`,
`updated_at`. El módulo `weight` la importa; el modelo permanece en `profile/models.py` para no mover
una tabla ya migrada (0002).

**Razón**: la restricción «un registro por día» y el rango ya están en la base; 002 escribe ahí el
peso del onboarding. Mover la tabla obligaría a una migración de renombrado sin valor (principio VII).

**Alternativas**: tabla nueva `weight_log` → descartada (duplicación y migración innecesaria).

## R2 — «Hoy» y fechas futuras (FR-001)

**Decisión**: la app envía `measured_on` como fecha **local** del móvil, bloquea el selector a hoy o
anterior y manda siempre `utc_offset_min` (obligatorio, −840…840, como el diario). El backend calcula
el «hoy» local exacto (`(now UTC + utc_offset_min).date()`) y rechaza con `400 VALIDATION_ERROR`
(`fields: [measured_on]`) cualquier fecha posterior; el mínimo es la fecha de alta (UTC) − 1 día. Usa un
validador propio y **no** `diary/day.py::validate_entry_date`, que lanza `DIARY_DATE_OUT_OF_RANGE` y
solo tolera «hoy UTC + 1 día».

**Razón**: FR-001 exige rechazar cualquier fecha posterior a hoy; con el desfase ya disponible el
servidor puede hacerlo sin depender de su propia zona.

**Alternativas**: reutilizar el margen de 1 día del diario → descartada (aceptaría «mañana» en una
petición directa); fecha del servidor sin desfase → descartada (el servidor no conoce la zona del móvil).

## R3 — Media semanal: función pura `weight/average.py` (FR-004, FR-009)

**Decisión**: módulo puro sin E/S ni reloj, con `Decimal` y `ROUND_HALF_UP`.

- `weekly_average(entries, as_of) -> Decimal | None`: media de los registros cuyo `measured_on` está
  en `[as_of − 6 días, as_of]` (ventana de 7 días incluido `as_of`). Devuelve `None` con menos de 3
  registros. El resultado se redondea a **1 decimal, medio hacia arriba**; ese único valor redondeado
  es el que se compara, se muestra y se usa en el recálculo.
- `exceeds_threshold(average, reference) -> bool`: `True` si
  `abs(average − reference) / reference > Decimal("0.02")` (**estrictamente mayor**). `reference` es el
  peso guardado con el objetivo vigente (`daily_target.calc_weight_kg`).
- `moving_average_series(entries, days) -> list[(date, Decimal|None)]`: para cada día con registro en
  el periodo, la media móvil de su ventana de 7 días **solo si** esa ventana tiene ≥3 registros; si no,
  `None` (sin punto de media ese día).

**Razón**: principio VI. El redondeo único antes de comparar evita discrepancias entre lo mostrado y lo
calculado (aclaración de la spec).

**Alternativas**: media sin redondear para comparar y redondear solo al mostrar → descartada por la
aclaración («ese único valor se usa para comparar, mostrar y recalcular»).

## R4 — Gráfica: puntos diarios + media móvil, sin interpolar huecos (FR-003, US2)

**Decisión**: la gráfica dibuja un punto por cada día con registro (peso diario) y una línea de media
móvil de 7 días; los días sin registro no se interpolan y la media solo aparece en días con ≥3
registros en su ventana. Periodos: 30 días, 90 días y «todo» (desde el primer registro). El backend
devuelve la serie ya calculada (`GET /v1/weight/chart`) para que el cálculo de la media sea el mismo
que el del recálculo y esté probado una sola vez; la app solo pinta. `fl_chart` para el lienzo.

**Alternativa textual accesible**: el mismo endpoint devuelve un resumen (peso actual, media semanal,
variación en el periodo) y la app muestra además la lista de registros navegable con lector de
pantalla. Con menos de 2 registros, mensaje explicativo (US2.4).

**Razón**: centralizar la media evita dos implementaciones (una en Dart, otra en Python) que podrían
divergir (principio VI).

**Alternativas**: calcular la media en el cliente → descartada (duplicaría la regla y sus pruebas).

## R5 — Persistencia de la propuesta: tabla `recalc_proposal` (FR-005, FR-007)

**Decisión**: tabla nueva `recalc_proposal` con una fila por propuesta. Estados `pending`, `accepted`,
`ignored`. Campos: `reference_weight_kg` (el `calc_weight_kg` vigente al crearla),
`weekly_average_kg`, `target_from_id` (objetivo vigente al proponer), `was_manual` (si ese objetivo
estaba editado a mano, para el aviso de FR-008), `created_at`, `responded_at`, `ignored_until`
(fecha, solo al ignorar). Índice parcial único: **como máximo una fila `pending` por usuario**.

**Flujo** (service):
- Al **guardar/editar/borrar** un peso y al **abrir la app** (`GET /v1/recalc-proposal`) se evalúa el
  umbral con la media semanal actual contra `calc_weight_kg` del objetivo vigente.
- Si procede y no hay `pending`, y no estamos dentro de un `ignored_until` vigente de una propuesta
  previa, se crea una fila `pending`. Si ya hay `pending`, se **actualiza** su `weekly_average_kg` (y
  los valores propuestos) para reflejar los datos actuales, de modo que al reabrir se ve la misma
  propuesta viva (FR-007, US3.7).
- **Aceptar** (`POST /v1/recalc-proposal/accept`): recalcula con `targets.recalculate` usando la media
  semanal como peso (ese peso pasa a ser el nuevo `calc_weight_kg`); marca la fila `accepted` con
  `responded_at`. El objetivo nuevo rige desde hoy (`effective_from`).
- **Ignorar** (`POST /v1/recalc-proposal/ignore`): marca `ignored` con `responded_at` e
  `ignored_until = hoy + 7 días`; no se vuelve a proponer hasta pasada esa fecha (FR-007).

**Razón**: la spec exige guardar la propuesta y su respuesta en el servidor y volver a mostrarla hasta
responder; el «ignorar 7 días» también en el servidor.

**Alternativas**: estado solo en el móvil → descartada por la aclaración de la sesión 2026-11-25.

## R6 — Referencia del 2% con objetivo editado a mano (FR-008)

**Decisión**: la referencia es siempre `daily_target.calc_weight_kg` del objetivo **vigente**, que
002 ya hereda del último cálculo también cuando el objetivo se edita a mano (`save_manual` copia
`calc_*`). Si el objetivo vigente tiene `source == "manual"`, la propuesta marca `was_manual = true` y
la app avisa de que aceptar sustituirá los valores editados. Nunca se recalcula sin aceptación.

**Razón**: coincide con `targets/service.py` (la referencia solo cambia al aceptar un recálculo).

## R7 — Variación muy grande (>10%) — Edge case

**Decisión**: la propuesta se genera igual; el endpoint marca `large_change = true` cuando
`abs(average − reference)/reference > 0.10`, y la app añade un aviso de «revisa si hay un registro
erróneo». No bloquea aceptar.

**Razón**: la spec pide avisar, no impedir.

## R8 — Recalcular solo afecta desde hoy — Edge case

**Decisión**: aceptar crea una versión nueva de `daily_target` con `effective_from = ahora`; los días
pasados del diario mantienen su objetivo porque `diary/day.py::pick_target` elige la versión vigente
al terminar cada día. Sin cambios en el diario.

**Razón**: el versionado de objetivos de 002 ya da este comportamiento.

## R9 — Offline — Edge case

**Decisión**: igual que el resto de la app (principio técnico de la constitución): ante fallo de red se
avisa y el peso escrito se conserva en el formulario (no se limpia el campo).

**Razón**: coherencia con 002–006.

## Resumen de decisiones

| Tema | Decisión |
|---|---|
| Almacén de peso | Reutilizar `weight_entry` (002) |
| «Hoy» | Fecha local del móvil; backend valida con margen de 1 día (patrón diario) |
| Media semanal | `weight/average.py` puro, 1 decimal HALF_UP, ≥3 registros |
| Gráfica | Serie calculada en backend; `fl_chart`; sin interpolar; alternativa textual |
| Propuesta | Tabla `recalc_proposal` persistida; 1 `pending` por usuario |
| Referencia 2% | `calc_weight_kg` del objetivo vigente; aviso si es manual |
| Recálculo | `targets.recalculate` con la media semanal como peso; rige desde hoy |
