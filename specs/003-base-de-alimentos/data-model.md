# Data Model: 003 — Base de alimentos

Migración `0003_foods` (sobre `0002_onboarding`): crea la extensión `pg_trgm` y las tablas
`food` y `food_import`. En el móvil no se guarda nada nuevo.

## Nutrientes

Son los mismos 12 nombres que usa `TargetValues` en la 002, así la 004 compara alimentos con el
objetivo sin convertir nada. Todos son valores **por 100 g o 100 ml** (según `base_unit`), de
tipo `NUMERIC(8,2)`, y `NULL` significa «sin dato» (FR-003).

| Columna | Unidad | Obligatorio | Máximo por 100 |
|---|---|---|---|
| `kcal` | kcal | sí | 900 |
| `protein_g` | g | sí | 100 |
| `carbs_g` | g | sí | 100 |
| `fat_g` | g | sí | 100 |
| `fiber_g` | g | no | 100 |
| `sodium_mg` | mg | no | 40.000 |
| `potassium_mg` | mg | no | 10.000 |
| `calcium_mg` | mg | no | 5.000 |
| `iron_mg` | mg | no | 500 |
| `magnesium_mg` | mg | no | 2.000 |
| `vitamin_d_ug` | µg | no | 1.000 |
| `vitamin_c_mg` | mg | no | 5.000 |

- Los cuatro obligatorios son `NOT NULL` en los tres tipos: un alimento sin ellos no se puede
  usar (R3, R7).
- Los máximos son `CHECK` de la base y validaciones de la API. Hay un `CHECK (x >= 0)` en todas
  las columnas.

## `food`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` PK | `gen_random_uuid()` |
| `kind` | `TEXT` | `generic` \| `packaged` \| `custom` |
| `owner_user_id` | `UUID` FK → `user_account.id`, nullable | Solo en `custom` |
| `name` | `TEXT` | 1–120 caracteres, en español |
| `brand` | `TEXT` nullable | ≤ 80 |
| `barcode` | `TEXT` nullable | GTIN normalizado (8, 13 o 14 dígitos, R9) |
| `base_unit` | `TEXT` | `g` \| `ml` |
| *12 nutrientes* | `NUMERIC(8,2)` | Ver tabla anterior |
| `serving_size` | `NUMERIC(7,2)` nullable | Ración en `base_unit`; `> 0` y `≤ 5000` |
| `synonyms` | `TEXT` nullable | Solo en `generic`; variantes separadas por `|` |
| `search_text` | `TEXT` | `normalize(name + brand + synonyms)` (R6) |
| `source` | `TEXT` | `ciqual` \| `off` \| `user` |
| `source_code` | `TEXT` nullable | Código CIQUAL en `generic` |
| `fetched_at` | `TIMESTAMPTZ` nullable | Última consulta a OFF, solo en `packaged` |
| `archived_at` | `TIMESTAMPTZ` nullable | Genérico que ya no está en la semilla (R4) |
| `deleted_at` | `TIMESTAMPTZ` nullable | Borrado lógico de un `custom` (R11) |
| `created_at`, `updated_at` | `TIMESTAMPTZ` | Hora del servidor (`clock`) |

**Restricciones**

- `ck_food_kind`: `kind IN ('generic','packaged','custom')`.
- `ck_food_owner`: `(kind = 'custom') = (owner_user_id IS NOT NULL)`.
- `ck_food_source`: `generic` ↔ `ciqual` con `source_code NOT NULL`; `packaged` ↔ `off` con
  `barcode` y `fetched_at NOT NULL`; `custom` ↔ `user`.
- `ck_food_deleted`: `deleted_at IS NULL OR kind = 'custom'`.
- `ck_food_archived`: `archived_at IS NULL OR kind = 'generic'`.
- `ck_food_barcode`: `barcode ~ '^[0-9]{8}$|^[0-9]{13,14}$'`.
- `ck_food_unit`: `base_unit IN ('g','ml')`.

**Índices**

- `uq_food_generic_code`: único `(source, source_code)` `WHERE kind = 'generic'`. Es la clave del
  *upsert* de la importación (FR-002).
- `uq_food_packaged_barcode`: único `(barcode)` `WHERE kind = 'packaged'`. Es la copia local
  compartida (FR-008).
- `uq_food_custom_barcode`: único `(owner_user_id, barcode)`
  `WHERE kind = 'custom' AND deleted_at IS NULL AND barcode IS NOT NULL`. Con un código repetido,
  `409 FOOD_BARCODE_TAKEN`.
- `ix_food_custom_owner`: `(owner_user_id)` `WHERE kind = 'custom' AND deleted_at IS NULL`.
- `ix_food_search_trgm`: GIN `(search_text gin_trgm_ops)`.

## `food_import`

Registro de cada importación de la semilla genérica (R4).

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` PK | |
| `source` | `TEXT` | `ciqual` |
| `edition` | `TEXT` | Edición de CIQUAL, leída de la cabecera de la semilla |
| `sha256` | `TEXT` | Hash del fichero de la semilla |
| `rows_upserted`, `rows_archived` | `INTEGER` | |
| `imported_at` | `TIMESTAMPTZ` | |

La importación no hace nada si el último `sha256` de `source = 'ciqual'` coincide con el del
fichero.

## Ciclo de vida

```text
generic:   (semilla) ──upsert──▶ activo ──ya no está en la semilla──▶ archivado
                                     ▲──────────vuelve a la semilla──────┘

packaged:  OFF found ──upsert──▶ fresco (≤ 30 días) ──tiempo──▶ caducado
                                     ▲──── nueva consulta a OFF ────┘
                                     (si OFF falla, se sirve caducado con stale: true)

custom:    creado ──editar──▶ creado (updated_at)
              └──eliminar──▶ eliminado (deleted_at; invisible, la fila se conserva)
```

## Reglas de acceso (principio V)

| Tipo | Quién lo ve | Quién lo cambia |
|---|---|---|
| `generic` | todos los usuarios con consentimiento | nadie desde la API (solo la importación) |
| `packaged` | todos los usuarios con consentimiento | nadie desde la API (solo la consulta a OFF) |
| `custom` | solo su dueño | solo su dueño |

- Toda consulta de `custom` filtra por `owner_user_id = usuario autenticado` y
  `deleted_at IS NULL`. El repositorio solo ofrece funciones que reciben `user_id`, igual que en
  la 002.
- Un `custom` de otro usuario, uno eliminado o un `id` que no existe responden igual:
  `404 FOOD_NOT_FOUND`.

## Validación de alimentos personalizados (FR-011, FR-014)

Ver R10 en `research.md`. En resumen:

- Bloquea: valores negativos, `protein_g + carbs_g + fat_g + fiber_g > 100`, máximos por 100,
  nombre vacío o demasiado largo, código no válido, `per_serving` sin `serving_size`.
- Avisa sin bloquear: `KCAL_MISMATCH` (> 15 % respecto a `4P + 4C + 9G`).

## Compromiso con la 004 (FR-015)

Una entrada del diario guarda `food_id` y una **copia** de los 12 valores por 100 y de la
`base_unit` en el momento de registrarla. Así, editar o eliminar el alimento, renovar la copia
de OFF o reimportar CIQUAL no cambian el pasado.
