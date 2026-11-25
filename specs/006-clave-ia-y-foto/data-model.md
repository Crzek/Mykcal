# Data Model: Clave de IA y registro por foto

Migración `0006_ai_key` (revisa `0005_quick`): una tabla nueva en PostgreSQL. En el móvil se añade
el almacenamiento local de borradores.

## Clave de IA — `ai_key` (nueva)

| Columna | Tipo | Reglas |
|---|---|---|
| `user_id` | `uuid` | PK. FK `user_account.id`, NOT NULL. Una clave por usuario. |
| `provider` | `text` | NOT NULL, CHECK `provider IN ('gemini')`. Proveedor del MVP. |
| `encrypted_key` | `bytea` | NOT NULL. `nonce ‖ ciphertext ‖ tag` de AES-256-GCM (research R1). |
| `configured_at` | `timestamptz` | NOT NULL. Cuándo se guardó o sustituyó por última vez. |

- **PK `user_id`**: cada usuario tiene como máximo una clave. Sustituirla es un `UPDATE`, no un
  `INSERT`.
- La columna `encrypted_key` nunca sale del backend: `GET /v1/ai-key` devuelve solo
  `{ has_key, provider, configured_at }` (research R3).
- Borrar la clave (`DELETE /v1/ai-key`) borra la fila (borrado físico: no hay historial ni
  deshacer; la spec no lo pide).
- El cifrado usa `AI_KEY_MASTER` de las variables de entorno (research R1). Sin esa variable el
  backend no arranca (validación en `Settings`).

## Análisis de foto (operación, sin tabla)

El análisis es una operación stateless en el servidor (research R8): recibe la foto, llama a
Gemini, empareja con la base y devuelve la propuesta. No se guarda en PostgreSQL.

El estado que describe la spec (pendiente → propuesto → guardado | borrador, FR-013) no es un
campo en ningún sitio: se infiere repartido entre tres componentes de la app — `pendiente`/
`propuesto` es el estado de `PendingAnalysisNotifier` (en memoria, no persistido), `guardado` es
la existencia de la(s) `diary_entry` creada(s), y `borrador` es la presencia del registro en
`drafts_store`. No hay un `status` que buscar en ningún modelo.

### Entrada: `POST /v1/photo-analysis`

| Campo | Tipo | Reglas |
|---|---|---|
| `photo` | `UploadFile` | Obligatorio. JPEG, ≤ 4 MB. Se lee en memoria y se descarta (FR-012). |
| `meal` | `text` | Obligatorio. Una de las 5 comidas. |
| `entry_date` | `date` | Obligatorio. Validación: alta ≤ fecha ≤ hoy (misma regla que la 004). |
| `description` | `text` | Opcional. Se añade al prompt para la IA. ≤ 500 caracteres. |
| `total_grams` | `integer` | Opcional. Pista para la IA; la suma propuesta puede diferir. |

### Salida: `PhotoAnalysisResult`

| Campo | Tipo | Descripción |
|---|---|---|
| `items` | `ProposedItem[]` | Lista de alimentos propuestos con su emparejamiento. |

### `ProposedItem`

| Campo | Tipo | Descripción |
|---|---|---|
| `ai_name` | `text` | Nombre devuelto por la IA. |
| `ai_grams` | `decimal(7,1)` | Gramos estimados por la IA. |
| `flagged` | `bool` | `true` si los gramos son absurdos (0 o > 2000). |
| `matched_food` | `FoodSummary \| null` | Alimento de la base más parecido, o `null` si no hay pareja. |
| `matched_similarity` | `float \| null` | Similitud (0–1) del emparejamiento. |
| `kcal` | `decimal \| null` | kcal calculadas con `matched_food` y `ai_grams`, o `null`. |
| `protein_g` | `decimal \| null` | Proteínas calculadas con `matched_food` y `ai_grams`, o `null`. |
| `carbs_g` | `decimal \| null` | Hidratos calculados con `matched_food` y `ai_grams`, o `null`. |
| `fat_g` | `decimal \| null` | Grasas calculadas con `matched_food` y `ai_grams`, o `null`. |

Los valores nutricionales (`kcal`, macros) se calculan con `matched_food` × `ai_grams / 100`
(principio II). Si `matched_food` es `null`, los cinco campos anteriores son `null`: el usuario
debe resolver el emparejamiento antes de guardar.

## Borrador de foto (almacenamiento local, app)

No existe en PostgreSQL. Se guarda en `shared_preferences` del móvil (research R12).

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | `String` (UUID) | Identificador local. |
| `meal` | `String` | Comida elegida. |
| `entry_date` | `String` (ISO date) | Día elegido. |
| `description` | `String?` | Descripción opcional que dio el usuario. |
| `total_grams` | `int?` | Gramos totales opcionales. |
| `failure_code` | `String?` | Código del fallo (research R11). `null` si es una propuesta pendiente. |
| `failure_reason` | `String?` | Mensaje en español para el usuario. `null` si es propuesta pendiente. |
| `photo_path` | `String` | Ruta local de la foto en el móvil. |
| `proposal_json` | `String?` | `PhotoAnalysisResult` serializado, si el análisis tuvo éxito pero el usuario aún no lo revisó. `null` en borradores con fallo. |
| `created_at` | `String` (ISO datetime) | Cuándo se creó el borrador. |

- Máximo 20 borradores. Al superar el límite se descarta el más antiguo.
- Se elimina cuando el usuario completa el borrador (guarda las entradas), lo completa a mano o lo
  descarta.
- Una propuesta pendiente (`failure_code == null, proposal_json != null`) es un análisis que se
  completó en segundo plano pero el usuario no lo abrió. Al tocarla se abre directamente la
  pantalla de edición de la propuesta sin repetir el análisis.
- Se pierde al cambiar de móvil (Assumptions de la spec).

## Guardar la propuesta

Guardar la propuesta no es una tabla nueva: se reutiliza `diary.service.create_entry` de la 004
para cada alimento confirmado. Cada llamada:
1. Recibe `food_id` (el `matched_food` confirmado por el usuario), `quantity` (los gramos
   confirmados), `entry_date` y `meal`.
2. Copia los valores nutricionales del alimento actual (principio II, FR-009).
3. Crea una `diary_entry` normal, igual que si se registrara por búsqueda o escáner.

No se añade ningún campo a `diary_entry` para distinguir las entradas creadas por foto: una vez
guardadas son entradas normales. Los recientes y favoritos de la 005 las incluyen sin cambios.

## Acceso (principio V)

| Dato | Filtro |
|---|---|
| Clave de IA | `ai_key.user_id = sub` |
| Análisis de foto | exige clave propia; la foto y la respuesta no se guardan |
| Borradores | almacenamiento local del móvil (un usuario, un dispositivo) |
| Entradas guardadas | `diary_entry.user_id = sub` (igual que la 004) |

Un usuario no puede leer, sustituir ni borrar la clave de otro. La petición de análisis usa la
clave propia; un usuario sin clave recibe `403 AI_KEY_REQUIRED`.
