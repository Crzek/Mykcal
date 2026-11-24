# Data Model: 004 — Diario de comidas y resumen diario

PostgreSQL 16. La migración Alembic `0004_diary` crea una tabla. Todo acceso se filtra por el
usuario autenticado (principio V).

## diary_entry

Entidad «Entrada» de la spec (FR-002–FR-005). «Día» y «Comida» no son tablas: son agrupaciones de
las entradas por `entry_date` y `meal` (research R4).

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `user_id` | `uuid` NOT NULL FK → `user_account.id` | |
| `entry_date` | `date` NOT NULL | Fecha local enviada por la app (R1) |
| `meal` | `text` NOT NULL | `CHECK IN ('breakfast','lunch','afternoon_snack','dinner','snacks')` |
| `food_id` | `uuid` NOT NULL FK → `food.id` | Alimento de origen. Para la 005 (recientes, copiar) |
| `food_kind` | `text` NOT NULL | Copia de `food.kind` |
| `food_name` | `text` NOT NULL | Copia de `food.name` |
| `food_brand` | `text` NULL | Copia de `food.brand` |
| `base_unit` | `text` NOT NULL | Copia: `CHECK IN ('g','ml')` |
| `serving_size` | `numeric(7,2)` NULL | Copia de `food.serving_size` |
| `kcal` … `fat_g` | `numeric(8,2)` NOT NULL | Copia **por 100** de los 4 obligatorios |
| `fiber_g` … `vitamin_c_mg` | `numeric(8,2)` NULL | Copia **por 100** de los 8 opcionales; `NULL` = sin dato |
| `quantity` | `numeric(7,1)` NOT NULL | g o ml. `CHECK (quantity > 0 AND quantity <= 10000)` |
| `servings` | `numeric(5,2)` NULL | Raciones si se registró así. `CHECK (servings IS NULL OR (servings > 0 AND servings <= 100))` |
| `created_at` | `timestamptz` NOT NULL | |
| `updated_at` | `timestamptz` NOT NULL | |
| `deleted_at` | `timestamptz` NULL | Borrado lógico (R8) |

Los 12 nutrientes tienen los mismos nombres que `food` y `daily_target`, en el orden de
`NUTRIENTS` (`foods/nutrients.py`).

Restricciones:

- `CHECK (servings IS NULL OR serving_size IS NOT NULL)`: no hay raciones sin tamaño de ración.
- Índice `ix_diary_entry_user_date (user_id, entry_date) WHERE deleted_at IS NULL`: consulta de un
  día.
- Sin unicidad por alimento: el mismo alimento puede aparecer varias veces en una comida
  (clarificación 1, R7).

### Valores de una entrada (no se guardan)

```text
valor(n) = copia_por_100(n) × quantity / 100       # Decimal, sin redondear
```

Si la copia de `n` es `NULL`, el valor es «sin dato» y el total del día y de su comida queda
incompleto en `n` (FR-008).

### Ciclo de vida

```text
          POST /entries                  PATCH (quantity/servings/meal)
(nada) ───────────────────► activa ◄──────────────────────────────┐
                              │ └──────────────────────────────────┘
               DELETE         │          ▲
                              ▼          │ POST /restore (≤ 60 s desde deleted_at)
                           borrada ──────┘
```

- **Crear**: copia el alimento (R5). `quantity` sale de la petición o de `servings × serving_size`
  redondeado a 1 decimal (R6).
- **Editar**:
  - Cambia `quantity`, `servings` o `meal`, y nunca `entry_date`, `food_*` ni la copia de
    nutrientes.
  - Enviar `servings` recalcula `quantity` con la `serving_size` **de la copia**.
  - Enviar `quantity` pone `servings = NULL`.
- **Borrar**: `deleted_at = now()`. La fila no se devuelve ni se suma.
- **Restaurar**: `deleted_at = NULL` si han pasado ≤ 60 s. Si no, `404 ENTRY_NOT_FOUND`.
- Nunca se borra físicamente: en el MVP no hay borrado de datos (constitución, «Datos»).

### Validación al crear

| Regla | Error |
|---|---|
| `entry_date` entre `created_at(UTC) − 1 día` y `hoy(UTC) + 1 día` | `400 DIARY_DATE_OUT_OF_RANGE` |
| Exactamente uno de `quantity` o `servings` | `400 VALIDATION_ERROR`, `fields: ["quantity","servings"]` |
| `servings` con alimento sin `serving_size` | `400 VALIDATION_ERROR`, `fields: ["servings"]` |
| `quantity` resultante > 10.000 | `400 VALIDATION_ERROR`, `fields: ["servings"]` o `["quantity"]` |
| Alimento inexistente, personalizado ajeno o borrado, o genérico archivado | `404 FOOD_NOT_FOUND` |

## Objetivo del día (de 002, sin cambios de esquema)

`daily_target` ya es un historial de versiones con `effective_from`. El objetivo de un día se elige
así (research R3):

```text
fin_del_día(D, offset) = timestamptz(D + 1, 00:00 UTC) − offset minutos
objetivo(D)            = argmax effective_from  where effective_from < fin_del_día
                         si no hay: la versión con menor effective_from
```

Usa el índice `ix_daily_target_user_effective (user_id, effective_from)` de la 002.

## user_account (de 001): sin cambios de esquema

`Me` expone `registered_at = created_at` (research R2).

## Valores calculados (no se guardan)

### `DiaryDay` (función pura `diary/summary.py`, research R10)

```text
entrada:  target (12 enteros), entradas activas del día (copia por 100, quantity, meal)
salida:
  totals:    consumido (12 valores redondeados), incomplete (lista de nutrientes)
  remaining: objetivo − consumido redondeado (puede ser negativo = exceso)
  meals[5]:  en el orden fijo; cada una con sus entradas y su total (kcal + 3 macros, incomplete)
```

Redondeo `ROUND_HALF_UP`: kcal y micros a entero; proteína, carbohidratos, grasa y fibra a 1
decimal. Se redondean los totales, no cada entrada antes de sumar.

## Reglas de acceso de las rutas nuevas

| Ruta | Sin cuenta | Desactivada | Sin consentimiento | Entrada ajena |
|---|---|---|---|---|
| `GET /v1/diary/days/{date}` | 403 `ACCOUNT_NOT_REGISTERED` | 403 `ACCOUNT_DISABLED` | 403 `CONSENT_REQUIRED` | — (solo ve las suyas) |
| `POST /v1/diary/entries` | 403 | 403 | 403 | — |
| `PATCH`/`DELETE /v1/diary/entries/{id}` | 403 | 403 | 403 | 404 `ENTRY_NOT_FOUND` |
| `POST /v1/diary/entries/{id}/restore` | 403 | 403 | 403 | 404 `ENTRY_NOT_FOUND` |

## Estado en la app (no persistido)

- `DiaryDayController` (por fecha): el `DiaryDay` de la última respuesta del servidor.
- `SelectedDate`: el día que se ve; «hoy» se recalcula al volver a primer plano.
- **Borrador de la hoja de cantidad**: cantidad, unidad y comida escritas. Se conservan si falla la
  red (caso límite «Sin conexión»). Solo en memoria.
- **Entrada pendiente de deshacer**: `id` de la última borrada, durante los 10 s del aviso.
