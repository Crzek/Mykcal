# Research: Registro rápido

No queda ningún «NEEDS CLARIFICATION»: las cinco dudas de la spec se cerraron en
`/speckit-clarify` (2026-11-24). Este documento fija las decisiones de diseño sobre lo que ya
construyó la 004 (`diary_entry` con copia por 100, `POST /v1/diary/entries`, borrado lógico).

## R1. Recientes es una consulta, no una tabla

- **Decision**: los recientes salen de `diary_entry` en cada petición:
  1. Se toma la última entrada activa (`deleted_at IS NULL`) de cada `food_id` del usuario,
     ordenando por `created_at DESC, id DESC` (`DISTINCT ON (food_id)`).
  2. Se cruza con `food` y se descartan los alimentos que ya no se pueden registrar: personalizado
     borrado y genérico archivado (las mismas reglas que `create_entry`).
  3. Se ordena por ese `created_at` descendente y se cortan 30 (FR-001).
- «Último uso» es `created_at` de la entrada, no `entry_date`: lo que el usuario registró hace un
  momento para ayer también es reciente. Cuentan todas las entradas, vengan de búsqueda, escáner,
  copia o (más adelante) foto.
- La lista es global, sin filtrar por comida (clarificación 1).
- **Rationale**: la spec la define como vista derivada. Con ≤ 50 usuarios, un usuario intenso
  tendría ~30 000 entradas en 5 años; el índice parcial `ix_diary_entry_user_date` ya acota por
  `user_id` y ordenar esas filas lleva milisegundos. No se añade índice (principio VII); se medirá
  si algún día pasa de 100 ms.
- **Alternatives considered**: tabla `recent_food` mantenida al crear o borrar entradas (dos
  fuentes de verdad, sin necesidad medida); filtrar después de cortar a 30 (devolvería menos de 30
  aunque hubiera más alimentos válidos).

## R2. Cantidad sugerida: la decide el servidor

- **Decision**: recientes y favoritos devuelven la misma pieza, `QuickFood`, con
  `suggested_quantity` y `suggested_servings`, listos para enviarse tal cual a
  `POST /v1/diary/entries`:
  - Con uso previo y la última entrada en raciones, si el alimento sigue teniendo la misma ración:
    `servings` de esa entrada.
  - Con uso previo en otro caso: `quantity` en g/ml de esa entrada.
  - Sin uso previo (solo favoritos): 1 ración si el alimento la tiene; si no, 100 g/ml (FR-004).
- **Rationale**: una sola regla, probada en el servidor. La app solo muestra y reenvía. Si la
  ración de un personalizado cambió, repetir «1 ración» cambiaría los gramos sin que el usuario lo
  vea; repetir los gramos no.
- **Alternatives considered**: calcularla en la app (regla duplicada en Dart); devolver siempre
  gramos (pierde «2 raciones», que es como el usuario piensa ese alimento).

## R3. Añadir con un toque usa la ruta de la 004

- **Decision**: el botón de añadir rápido llama a `POST /v1/diary/entries` con `food_id` y la
  cantidad sugerida. No hay ruta nueva para añadir.
- Para deshacer, la app necesita el id de la entrada creada. La respuesta sigue siendo `DiaryDay`
  (la app de la 004 no cambia) y se añade la cabecera estándar
  `Location: /v1/diary/entries/{id}`.
- **Rationale**: un único camino de alta, con sus validaciones y su copia del alimento
  (principio II). La cabecera es aditiva y no rompe el contrato.
- **Alternatives considered**: cambiar el cuerpo a `{day, entry_id}` (rompe la 004); buscar en el
  día la entrada más nueva de ese alimento (frágil si hay dos iguales).

## R4. Deshacer: 5 s en la app, 60 s en el servidor

- **Decision**:
  - Añadido rápido: «Deshacer» llama a `DELETE /v1/diary/entries/{id}` (borrado lógico de la
    004). No necesita plazo en el servidor: borrar una entrada propia siempre está permitido.
  - Copia: «Deshacer» llama a `DELETE /v1/diary/copies/{copy_id}`, que borra (lógicamente) solo las
    entradas con ese `copy_id` que sigan activas. El servidor la admite durante 60 s desde la copia;
    después responde `404 COPY_NOT_FOUND`.
  - El aviso de la app dura 5 s (clarificación 2, FR-007) y después desaparece.
  - Quitar un favorito desde su pestaña también muestra un aviso de 5 s con «Deshacer» (vuelve a
    marcarlo). FR-007 no lo exige: es una mejora sin coste, porque `PUT` es idempotente y
    reutiliza el mismo aviso.
- **Rationale**: el mismo margen de red que en la 004 (R8 de la 004). El usuario solo ve 5 s.
  Agrupar por `copy_id` garantiza que se borran solo las copiadas (US3.5), aunque la comida tuviera
  entradas antes o el usuario añada otras en esos segundos.
- **Alternatives considered**: deshacer la copia enviando la lista de ids (N peticiones o una ruta
  de borrado masivo genérica, más superficie); sin plazo en el servidor (una copia antigua podría
  borrarse en bloque por error).

## R5. Copiar una comida: una petición atómica

- **Decision**: `POST /v1/diary/copies` con `source_date`, `source_meal`, `target_date` y
  `target_meal`. En una transacción:
  1. Valida `target_date` con las reglas de la 004 (alta ≤ fecha ≤ hoy).
  2. Exige `target_date − 14 ≤ source_date < target_date` (FR-005, clarificación 3).
  3. Lee las entradas activas de la comida origen. Si no hay, `400 COPY_SOURCE_EMPTY`.
  4. Crea una entrada nueva por cada una, en el mismo orden, con un `copy_id` común (R4) y sin
     tocar las originales (SC-003).
  5. Devuelve `201 DiaryCopyResult { copy_id, entry_ids, day }`, con el día destino completo.
- Se puede copiar a cualquier comida del día visible (US3.4) y se añade a lo que ya hay (US3.3).
- **Rationale**: todo o nada; el resumen se actualiza en un solo viaje, como en la 004 (R9 de la
  004).
- **Alternatives considered**: que la app cree las entradas una a una (copia a medias si falla la
  red, N viajes); permitir copiar del mismo día (la spec habla de «otro día»; se añade si se pide).

## R6. Valores de la copia (FR-006)

- **Decision**: por cada entrada origen:
  - **Alimento disponible** (`foods_repository.get_visible` y genérico no archivado): la copia toma
    del alimento actual el nombre, la marca, la unidad, la ración y los 12 nutrientes por 100,
    igual que `create_entry`. Mantiene los g/ml de la entrada origen. Mantiene sus raciones solo si
    la ración del alimento no cambió; si cambió, guarda solo g/ml.
  - **Alimento no disponible** (personalizado borrado, genérico archivado): la copia conserva la
    copia por 100 de la entrada origen, su cantidad y sus raciones.
- **Rationale**: principio II, «valores siempre desde la base». Con el alimento borrado no hay base
  que consultar y lo más fiel es lo que se registró. Mantener los gramos refleja lo que se comió.
- **Alternatives considered**: copiar siempre la entrada tal cual (contradice FR-006); recalcular
  los gramos con la ración nueva (cambia la cantidad comida sin avisar).

## R7. Lista de comidas para copiar

- **Decision**: `GET /v1/diary/copy-sources?target_date=…&target_meal=…` devuelve los días entre
  `target_date − 14` y `target_date − 1` que tienen alguna entrada, del más reciente al más antiguo.
  En cada día, solo las comidas con entradas: primero la del mismo tipo que `target_meal`, y luego
  el resto en el orden fijo de la 004. Cada comida trae sus entradas (nombre, cantidad, raciones,
  kcal) y su total de kcal, calculados con la copia de la entrada.
- Las kcal mostradas son las de la entrada origen. Si un personalizado se editó después, la copia
  puede salir con otras kcal (R6). La hoja de confirmación lo explica con una línea cuando ocurre
  (`values_changed: true` en la comida).
- **Rationale**: una sola consulta por `(user_id, entry_date)` con el índice de la 004. La app
  pinta la lista sin más viajes (SC-002: < 15 s).
- **Alternatives considered**: pedir día a día con `GET /v1/diary/days/{date}` (14 viajes y
  objetivos que no se usan).
- **Nota**: la clarificación 3 decía «los últimos 14 días con registros», en conflicto con FR-005 y
  US3.1. Se resolvió a favor de FR-005 (2026-11-24): 14 días naturales anteriores al día visible,
  omitiendo los vacíos; la clarificación 3 de `spec.md` ya lo recoge.

## R8. Favoritos: tabla propia

- **Decision**: tabla `favorite_food (user_id, food_id, created_at)` con clave primaria
  `(user_id, food_id)`.
  - `PUT /v1/foods/favorites/{food_id}` marca (idempotente) y `DELETE` desmarca (idempotente). Las
    dos devuelven `204`.
  - Marcar un alimento que el usuario no puede ver (personalizado ajeno o borrado, genérico
    archivado, id inexistente) da `404 FOOD_NOT_FOUND`, igual que en la 003.
  - `GET /v1/foods/favorites` devuelve `QuickFood[]` ordenados por último uso descendente (mismo
    cálculo que R1). Los nunca usados van al final, por nombre sin tildes ni mayúsculas (`normalize`
    de la 003) (FR-010).
  - Un favorito cuyo alimento deja de estar disponible no se lista. La fila se queda (no hay
    restauración de personalizados, pero tampoco molesta) y el `PUT` de un alimento no disponible
    no la crea.
- Sin límite de favoritos: con un uso realista son decenas.
- **Rationale**: es el único dato nuevo que la spec pide guardar («Favorito: alimento marcado por
  un usuario, con su fecha»).
- **Alternatives considered**: columna `is_favorite` en `food` (los genéricos son compartidos);
  borrar la fila al borrar el personalizado (acopla la 003 a la 005 sin beneficio).

## R9. ¿Cómo sabe la app si un alimento es favorito?

- **Decision**: la app carga `GET /v1/foods/favorites` una vez por sesión en un
  `favoritesController` y deriva de él un `Set<foodId>`. La estrella de la búsqueda, de recientes y
  de la hoja de una entrada lee ese conjunto y lo actualiza al momento (optimista; si la petición
  falla, se revierte y se avisa). `QuickFood` trae además `is_favorite` para la pestaña de
  recientes.
- **Rationale**: no hay que tocar `FoodSummary` ni `DiaryEntry` de la 003 y la 004.
- **Alternatives considered**: añadir `is_favorite` a la búsqueda y a cada entrada (cambia tres
  contratos y obliga a recargar el día al marcar).

## R10. Rutas y orden de registro

- **Decision**: paquete nuevo `mykcal.quick` con:
  - `GET /v1/foods/recent`
  - `GET /v1/foods/favorites`, `PUT` y `DELETE /v1/foods/favorites/{food_id}`

  Las rutas de copia van en el router de `diary`.

  El router de `quick` se registra **antes** que el de `foods`: si no, `GET /v1/foods/{food_id}`
  captura `recent` y `favorites` y responde 422.
- Todas exigen cuenta activa y consentimiento (`require_consent`) y se añaden a
  `test_consent_gate`. No hay rutas públicas nuevas.
- Errores nuevos en `ErrorCode`: `COPY_SOURCE_EMPTY` (400) y `COPY_NOT_FOUND` (404, mismo cuerpo
  para una copia inexistente, ajena o fuera de plazo).
- **Rationale**: recientes y favoritos son «alimentos para añadir», como la búsqueda; la copia es
  del diario.

## R11. Registros (principio X)

- **Decision**: eventos `favorite_added`, `favorite_removed`, `diary_meal_copied` (con
  `entries_count`) y `diary_copy_undone`, con `user_id`, comidas y duración. Nunca el alimento, la
  cantidad ni las fechas. Se amplía `test_logs_no_secrets`. Listar recientes o favoritos no deja
  evento.

## R12. App: la pantalla de añadir

- **Decision**: la búsqueda en modo selección de la 004 gana dos pestañas, **Recientes** y
  **Favoritos**, que se ven mientras el campo de búsqueda está vacío. Al escribir se ven los
  resultados, como ahora.
  - Cada fila: tocar el nombre abre la hoja de cantidad de la 004 con la cantidad sugerida; el
    botón «+» añade con esa cantidad. Su etiqueta para el lector de pantalla nombra el alimento y la
    cantidad: «Añadir Pan blanco, 60 g» (FR-009).
  - Tras añadir rápido, la pantalla sigue abierta para añadir más. Aparece un aviso de 5 s
    «Pan blanco añadido a Desayuno» con «Deshacer», y el día se actualiza con la respuesta.
  - «Copiar de otro día» se abre desde el menú de cada comida del diario.
- Detalle en `contracts/ui-flows.md`.
- **Rationale**: reutiliza la pantalla que ya conoce el usuario (SC-001: un toque desde añadir).

## R13. Pruebas

- **Backend**:
  - Unitarias puras: `suggest_amount` (R2), orden de favoritos (R8), orden de las comidas origen
    (R7) y regla de valores de la copia (R6), con los casos de `contracts/quick-cases.md`.
  - Integración con testcontainers: recientes (distintos, 30, orden, borrados y archivados),
    favoritos (idempotencia, orden, no disponibles), copia (ventana de 14 días, destino con
    entradas, origen intacto, valores actuales o conservados, deshacer y plazo de 60 s) y
    cabecera `Location`.
  - Contrato contra `openapi.yaml` 0.5.0.
  - `privacy`: `test_user_isolation_quick` (SC-004), puerta de consentimiento, identidad y
    registros.
- **App**: flutter_test + mocktail. Pestañas y estado vacío, «+» y etiqueta semántica, deshacer de
  5 s, estrella optimista y hoja de copiar.

## R14. Dependencias nuevas

- Ninguna, ni en el backend ni en la app.
