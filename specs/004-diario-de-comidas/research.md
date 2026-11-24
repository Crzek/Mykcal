# Research: 004 — Diario de comidas y resumen diario

Decisiones técnicas de la feature. Ninguna queda como «NEEDS CLARIFICATION»: las tres dudas de la
spec se cerraron en `/speckit-clarify` (2026-11-24).

## R1. El día es una fecha local que envía la app

- **Decision**: cada día del diario es un `date` (`AAAA-MM-DD`) calculado en el móvil con su hora
  local. El servidor no guarda la zona horaria del usuario. Valida solo un rango de saneamiento:
  - **Máximo**: hoy en UTC + 1 día, igual que `weight_entry.measured_on` (002, R6).
  - **Mínimo**: la fecha UTC de `user_account.created_at` − 1 día.

  La app aplica el límite exacto (desde el día local del alta hasta hoy). El servidor solo evita
  fechas absurdas, con un día de margen por la zona horaria. Fuera del rango, `400
  DIARY_DATE_OUT_OF_RANGE`.
- **Rationale**: es la regla de la spec («fecha local del móvil») y el mismo patrón que el peso de
  la 002. Guardar la zona horaria obligaría a mantenerla al viajar y no aporta nada a 50 usuarios.
- **Alternatives considered**: guardar `timestamptz` y derivar el día (depende de la zona en cada
  consulta); guardar la zona IANA en el perfil (otro dato que mantener y otro paquete en Flutter).

## R2. Fecha de alta disponible para la app

- **Decision**: `Me` añade `registered_at` (`timestamptz`, de `user_account.created_at`). La app lo
  pasa a fecha local y lo usa como primer día del calendario y de la flecha «anterior».
- **Rationale**: la app ya pide `GET /v1/me` al arrancar. Es un campo nuevo opcional en el
  contrato y no rompe clientes.
- **Alternatives considered**: devolver `min_date` en cada día del diario (repite el dato en todas
  las respuestas y obliga a pedir un día para pintar el calendario).

## R3. Objetivo vigente en un día (FR-011)

- **Decision**: el objetivo de un día `D` es la versión de `daily_target` con el mayor
  `effective_from` anterior al final de `D` en hora local. La app envía `utc_offset_min` (el
  desfase de su zona al final de ese día, de −840 a 840) en cada petición del diario. El servidor
  calcula:

  ```text
  fin_del_día = (D + 1 día) a las 00:00 − utc_offset_min   (instante UTC)
  objetivo    = versión con effective_from < fin_del_día y mayor effective_from
  ```

  Si no hay ninguna (días entre el alta y el primer objetivo), se usa la versión más antigua del
  usuario. Si el usuario no tiene ninguna versión, `404 TARGET_NOT_FOUND` (no debería pasar: la
  app solo enseña el diario con `onboarding = done`).
- **Rationale**: cumple el caso límite de la spec («hoy usa el objetivo vigente al terminar el
  día»): para hoy, el final del día es futuro, así que sale la versión vigente. Para días pasados,
  sale la que regía al cerrar ese día. Usa el índice `ix_daily_target_user_effective` que la 002
  dejó para esto. Dart da el desfase de cualquier fecha (`DateTime(...).timeZoneOffset`) sin
  paquetes y con el horario de verano correcto.
- **Alternatives considered**: comparar por fecha UTC de `effective_from` (falla en el cambio de
  día cerca de medianoche); guardar una copia del objetivo en cada día (otra tabla y datos
  duplicados que ya están versionados).

## R4. Una tabla `diary_entry`; día y comida no son tablas

- **Decision**: solo se crea `diary_entry` con `user_id`, `entry_date`, `meal` y la copia del
  alimento. «Día» y «Comida» de la spec son agrupaciones de las entradas, no filas.
  Las comidas son un enum fijo: `breakfast` (desayuno), `lunch` (comida), `afternoon_snack`
  (merienda), `dinner` (cena) y `snacks` (picoteo), en ese orden (FR-001).
- **Rationale**: las comidas son fijas y sin datos propios (supuesto de la spec), y el objetivo del
  día se deduce del historial (R3). Una tabla por concepto añadiría filas vacías y transacciones
  sin valor (principio VII).
- **Alternatives considered**: tablas `diary_day` y `meal` (sin columnas propias en el MVP).

## R5. La entrada copia el alimento por 100 g/ml, no los totales

- **Decision**: al crear una entrada se copian del alimento el nombre, la marca, `base_unit`,
  `serving_size` y los 12 nutrientes **por 100**. Junto a ellos se guarda la cantidad en g/ml y,
  si se registró en raciones, el número de raciones. Los valores de la entrada se calculan siempre
  como `por_100 × cantidad / 100` a partir de esa copia: al crearla, al editar la cantidad y al
  sumar el día.
- **Rationale**:
  - Cumple FR-004 y SC-004: cambios posteriores del alimento no alteran la entrada, ni siquiera al
    editar la cantidad.
  - Cumple FR-003: los valores salen de la base y nunca se escriben a mano.
  - Una sola fórmula para todo, que ya existe (`sum_nutrients` de la 003).
  - La 005 (copiar comida, recientes) tendrá el `food_id` y la copia para el caso «alimento
    borrado».
- **Alternatives considered**: guardar los totales de la entrada (al editar la cantidad habría que
  volver al alimento, que pudo cambiar o borrarse); no copiar nada y leer siempre el alimento
  (incumple FR-004).

## R6. Cantidad en g/ml o en raciones (FR-002, clarificación 2)

- **Decision**: la petición lleva exactamente uno de estos dos campos:
  - `quantity`: g o ml, > 0 y ≤ 10.000, con 1 decimal como máximo.
  - `servings`: > 0 y ≤ 100, con 2 decimales como máximo. Solo vale si el alimento tiene
    `serving_size`; si no, `400 VALIDATION_ERROR` con `fields: ["servings"]`. El servidor guarda
    `quantity = servings × serving_size`, redondeado a 1 decimal con `ROUND_HALF_UP`.

  La entrada guarda `servings` (nulo si se registró en g/ml). Al editar, la app abre el formulario
  en la misma unidad y deja pasar a g/ml (clarificación 2). Guardar en g/ml pone `servings` a
  nulo. Por encima de 5.000 g/ml la app pide confirmación antes de enviar (caso límite); el
  servidor acepta hasta 10.000.
- **Rationale**: `serving_size` de la copia mantiene la conversión estable aunque el alimento
  cambie su ración. El tope de 10.000 es de saneamiento.
- **Alternatives considered**: guardar solo gramos (pierde la unidad para editar, contra la
  clarificación 2); dejar que la app calcule los gramos (dos sitios con la misma regla).

## R7. Mismo alimento varias veces (clarificación 1)

- **Decision**: no hay restricción de unicidad por alimento y comida. Cada `POST` crea una fila
  nueva.
- **Rationale**: decisión de Erick. Cada registro conserva su cantidad y su copia, y deshacer o
  editar uno no toca otro.

## R8. Borrar con deshacer de 10 segundos (FR-005, clarificación 3)

- **Decision**: borrado lógico en el servidor:
  - `DELETE /v1/diary/entries/{id}` pone `deleted_at = now()` y devuelve el día actualizado. El
    resumen cambia al momento.
  - La app muestra un `SnackBar` de 10 s con «Deshacer».
  - Deshacer llama a `POST /v1/diary/entries/{id}/restore`, que pone `deleted_at = NULL`. El
    servidor acepta restaurar hasta 60 s después del borrado: 10 s de la app más margen de red.
    Pasado ese plazo, `404 ENTRY_NOT_FOUND`.
  - Las entradas borradas no se devuelven ni se suman nunca.
- **Rationale**: el servidor es siempre la verdad, así que los totales no se calculan en dos
  sitios. Si la app se cierra durante los 10 s, el borrado ya está hecho, que es lo que el usuario
  pidió. Restaurar es seguro porque la copia de valores no cambia (no se vuelve al alimento).
- **Alternatives considered**: retrasar el `DELETE` en la app hasta que acabe el aviso (si la app
  se cierra, la entrada «borrada» vuelve, y el resumen tendría que calcularse en local); recrear la
  entrada con un `POST` (los valores saldrían del alimento actual y podrían cambiar, contra FR-004).

## R9. Las rutas que cambian un día devuelven el día completo

- **Decision**: crear, editar, borrar y restaurar responden con el `DiaryDay` completo y
  recalculado, igual que `GET /v1/diary/days/{date}`. Todas reciben `utc_offset_min` (R3). La app
  sustituye su estado por la respuesta.
- **Rationale**: SC-003 (resumen al instante) con un solo viaje de red y sin sumar en la app.
  Un día tiene decenas de entradas, así que la respuesta es pequeña.
- **Alternatives considered**: devolver solo la entrada y pedir el día otra vez (dos viajes);
  sumar en la app (duplica la regla de redondeo y el «incompleto»).

## R10. Cálculo y redondeo del resumen (FR-006–FR-009, SC-002)

- **Decision**: función pura `diary/summary.py`:
  1. Valores de cada entrada: `por_100 × cantidad / 100` en `Decimal`, sin redondear.
  2. Totales de cada comida y del día: `sum_nutrients` de la 003, con `None` como 0 y el nutriente
     marcado como incompleto (FR-008).
  3. Redondeo para mostrar, `ROUND_HALF_UP`: kcal y micros en mg/µg a entero; proteína,
     carbohidratos, grasa y fibra a 1 decimal. Se redondea solo el total, no cada entrada.
  4. `restante = objetivo − consumido_redondeado`. Si es negativo se devuelve igual, negativo, y
     la app lo muestra como exceso («+150 kcal»). Así `consumido + restante = objetivo` siempre se
     cumple con los números que ve el usuario (SC-002).
  5. Sodio: es un máximo. Se devuelve igual (`restante` = lo que queda hasta el límite, FR-007).

  Los valores de cada entrada se devuelven redondeados igual que los totales, solo para mostrarse.
- **Rationale**: un solo sitio calcula. Con casos conocidos en pruebas unitarias (principio VI).
- **Alternatives considered**: redondear cada entrada y sumar (los totales no coincidirían con la
  suma exacta).

## R11. Rutas, acceso y errores

- **Decision**: 5 rutas nuevas, todas con `require_consent` (cuenta activa y consentimiento, como
  en la 003 R14):

  | Ruta | Uso |
  |---|---|
  | `GET /v1/diary/days/{date}` | Día con resumen y comidas |
  | `POST /v1/diary/entries` | Añadir |
  | `PATCH /v1/diary/entries/{id}` | Cantidad y/o comida |
  | `DELETE /v1/diary/entries/{id}` | Borrado lógico |
  | `POST /v1/diary/entries/{id}/restore` | Deshacer |

  Errores nuevos: `DIARY_DATE_OUT_OF_RANGE` (400) y `ENTRY_NOT_FOUND` (404). Una entrada de otro
  usuario da `404 ENTRY_NOT_FOUND`, indistinguible de una inexistente (principio V).
  Añadir un personalizado ajeno o borrado, o un genérico archivado, da `404 FOOD_NOT_FOUND`.
  `PATCH` no cambia la fecha: mover solo vale dentro del mismo día (FR-005).
- **Rationale**: mismo patrón que `/v1/foods/**`. No hay rutas públicas nuevas.

## R12. Registros sin contenido sensible (principio X)

- **Decision**: eventos `diary_entry_created`, `diary_entry_updated`, `diary_entry_deleted` y
  `diary_entry_restored` con `user_id`, `meal` y `duration_ms`. Nunca el nombre del alimento, la
  cantidad, la fecha ni los valores: dicen qué come una persona. `test_logs_no_secrets` se amplía.

## R13. App: el diario es la pantalla principal (FR-012)

- **Decision**:
  - `HomeScreen` pasa a ser el diario de hoy: cabecera de día con flechas «anterior» y
    «siguiente» y un botón de calendario (`showDatePicker`, de la fecha de alta a hoy), la tarjeta
    de resumen y las 5 comidas. El menú ⋮ no cambia.
  - El saludo y el botón «Alimentos» de la 003 se quitan de Inicio. «Alimentos» pasa al menú ⋮,
    para seguir llegando a «Mis alimentos» y crear personalizados sin registrar.
  - `TargetCard` deja Inicio. Su contenido (ver y editar el objetivo) se abre desde la tarjeta de
    resumen («Ver objetivo»).
  - Estado: `DiaryDayController` (Riverpod, `AsyncNotifier.family` por fecha) guarda el `DiaryDay`
    del servidor y lo sustituye con cada respuesta (R9).
  - Añadir: «+» en cada comida → `FoodSearchScreen` en modo selección (devuelve el alimento en vez
    de abrir el detalle; también el escáner) → hoja `EntryQuantitySheet` con cantidad, unidad
    (g/ml o raciones), vista previa calculada en vivo y «Añadir».
  - La vista previa usa la misma fórmula que el servidor (`entry_math.dart`, pura). El servidor
    manda: la app sustituye su estado por la respuesta.
  - Editar: tocar una entrada abre la misma hoja con cantidad, unidad y un selector de comida, y un
    botón «Borrar».
  - Medianoche: al volver la app al primer plano (`AppLifecycleState.resumed`), si el usuario
    estaba en «hoy» y la fecha local cambió, se pasa al día nuevo (caso límite).
  - Sin conexión: la hoja no se cierra y conserva lo escrito. Se muestra el error de conexión con
    «Reintentar» (patrón de la 002).
- **Rationale**: reutiliza la búsqueda, el escáner y `nutrient_format.dart` de la 003, y no añade
  ninguna dependencia nueva.
- **Alternatives considered**: `PageView` para deslizar entre días (más estado y pruebas; las
  flechas bastan para el MVP); paquete de calendario (`showDatePicker` cumple).

## R14. Accesibilidad del resumen (FR-014)

- **Decision**:
  - El exceso se muestra con texto («+150 kcal por encima»), un icono y color de error. Nunca solo
    con color.
  - Cada fila del resumen es un único nodo `Semantics` con frase completa: «Calorías: 1.850 de
    2.000, quedan 150».
  - «Incompleto» es texto con icono de aviso, y su explicación sale en un `Tooltip` accesible.
  - Las barras de progreso son decorativas (`ExcludeSemantics`).
  - Botones con área ≥ 48 dp. Números con formato español (`core/format/numbers.dart`).

## R15. Pruebas

- **Decision**:
  - **Backend unitarias**: `summary.py` (redondeo, exceso, incompleto, sodio, SC-002 con casos
    fijos), conversión de raciones y `day_end_utc` (desfases, cambio de hora).
  - **Backend integración** (testcontainers): crear, editar, mover, borrar y restaurar;
    objetivo vigente por día con varias versiones (FR-011); límites de fecha; mismo alimento dos
    veces; la entrada no cambia al editar o borrar el personalizado (SC-004).
  - **Contrato**: `test_diary_contract.py` contra `openapi.yaml` 0.4.0.
  - **Privacidad**: `test_user_isolation_diary.py` (SC-005, las 5 rutas con entradas ajenas), y
    ampliar `test_consent_gate.py`, `test_all_routes_require_identity.py` y
    `test_logs_no_secrets.py`.
  - **App** (flutter_test + mocktail): `entry_math` pura, resumen (exceso con texto, incompleto,
    semántica), hoja de cantidad (raciones, validación, confirmación de > 5.000, conserva lo
    escrito si falla la red), navegación de días (límites, medianoche), deshacer de 10 s.

## R16. Dependencias nuevas

- **Decision**: ninguna, ni en el backend ni en la app.
