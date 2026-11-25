# Data Model: Registro rápido

Migración `0005_quick` (revisa `0004_diary`): una tabla nueva y una columna en `diary_entry`. En el
móvil no se guarda nada nuevo.

## Favorito — `favorite_food` (nueva)

| Columna | Tipo | Reglas |
|---|---|---|
| `user_id` | `uuid` | FK `user_account.id`, NOT NULL. Parte de la PK. |
| `food_id` | `uuid` | FK `food.id`, NOT NULL. Parte de la PK. |
| `created_at` | `timestamptz` | NOT NULL. Cuándo se marcó. |

- **PK** `(user_id, food_id)`: un alimento es favorito una sola vez por usuario. Marcar dos veces
  no duplica (`INSERT … ON CONFLICT DO NOTHING`).
- Desmarcar borra la fila (borrado físico: no hay nada que deshacer ni historial que guardar).
- Solo se puede crear si el alimento es visible para el usuario y se puede registrar
  (`get_visible` y genérico no archivado); si no, `404 FOOD_NOT_FOUND` (research R8).
- Se lista solo si el alimento sigue disponible. La fila de un personalizado borrado se queda, sin
  efecto.
- No guarda datos de salud: dice qué alimentos le gustan a alguien, igual que un personalizado. Se
  trata con el mismo aislamiento.

## Entrada — `diary_entry` (de la 004, cambia)

| Columna nueva | Tipo | Reglas |
|---|---|---|
| `copy_id` | `uuid` | NULL. Igual en todas las entradas creadas por una misma copia; NULL en las demás. |

- Índice parcial `ix_diary_entry_copy (user_id, copy_id) WHERE copy_id IS NOT NULL`, para deshacer
  sin recorrer el diario del usuario.
- Una copia es una entrada nueva e independiente (spec, Key Entities): tiene su propio `id`,
  `created_at = ahora`, la `entry_date` y la `meal` destino y su propia copia por 100 (research R6).
  Editarla o borrarla no afecta a la original, ni al revés.
- El resto de columnas, restricciones y el índice `ix_diary_entry_user_date` no cambian.

## Reciente (vista derivada, sin tabla)

Se calcula en cada `GET /v1/foods/recent` (research R1):

| Campo | Origen |
|---|---|
| alimento | `food` actual, si sigue disponible |
| última cantidad | `quantity`, `servings` y `serving_size` de la última entrada activa de ese alimento |
| último uso | `created_at` de esa entrada |

- Un alimento aparece una vez (`DISTINCT ON (food_id)`), aunque se registrara muchas veces.
- Como máximo 30, por último uso descendente.
- Entradas borradas (`deleted_at`) no cuentan. Si se borra la única entrada de un alimento, deja de
  ser reciente; si se restaura, vuelve.

## QuickFood (respuesta, no se guarda)

Lo que devuelven recientes y favoritos:

| Campo | Regla |
|---|---|
| `food` | `Food` de la 003, con los valores actuales (para la vista previa) |
| `suggested_quantity` | g/ml, 1 decimal; siempre presente |
| `suggested_servings` | raciones o `null` (research R2) |
| `last_used_at` | `created_at` de la última entrada, o `null` si nunca se usó |
| `is_favorite` | si el usuario lo tiene marcado |

**Cantidad sugerida** (`quick/suggest.py`, puro), con `last` = última entrada activa:

1. `last` existe, tiene `servings` y `last.serving_size == food.serving_size` →
   `servings = last.servings`, `quantity = last.servings × food.serving_size`.
2. `last` existe en otro caso → `quantity = last.quantity`, `servings = null`.
3. Sin `last` y `food.serving_size` → `servings = 1`, `quantity = food.serving_size`.
4. Sin `last` ni ración → `quantity = 100`, `servings = null`.

La app envía a `POST /v1/diary/entries` `servings` si no es `null` y, si no, `quantity`.

## Copia de una comida (operación)

Entrada `DiaryCopyCreate`:

| Campo | Regla |
|---|---|
| `source_date` | `target_date − 14 ≤ source_date < target_date` |
| `source_meal` | una de las 5 comidas |
| `target_date` | alta ≤ fecha ≤ hoy (`validate_entry_date` de la 004) |
| `target_meal` | una de las 5 comidas; puede ser distinta de `source_meal` |

Fuera de rango: `400 DIARY_DATE_OUT_OF_RANGE`. Origen sin entradas activas:
`400 COPY_SOURCE_EMPTY`.

**Valores de cada entrada copiada** (`diary/copy_rules.py`, puro; research R6):

| Situación del alimento | Copia por 100, nombre, marca, unidad, ración | `quantity` | `servings` |
|---|---|---|---|
| Disponible, ración sin cambios | del alimento actual | de la origen | de la origen |
| Disponible, ración distinta o eliminada | del alimento actual | de la origen | `null` |
| No disponible | de la entrada origen | de la origen | de la origen |

`food_id` y `food_kind` siempre de la entrada origen.

## Ciclo de vida de una copia

```text
(no existe) ──POST /v1/diary/copies──▶ activa (N entradas con el mismo copy_id)
activa ──DELETE /v1/diary/copies/{copy_id} (≤ 60 s)──▶ deshecha (esas entradas con deleted_at)
activa ──pasan 60 s──▶ entradas normales (se editan y borran una a una, como en la 004)
```

- Deshacer borra solo las entradas de la copia que sigan activas. Si el usuario ya borró alguna,
  no pasa nada.
- Deshacer después de 60 s, dos veces, o el `copy_id` de otro usuario: `404 COPY_NOT_FOUND`.
- Las entradas de una copia deshecha se pueden restaurar una a una con la ruta `restore` de la 004
  durante sus 60 s, pero la app no lo ofrece.

## Acceso (principio V)

| Dato | Filtro |
|---|---|
| Recientes | `diary_entry.user_id = sub` y `food` visible para ese usuario |
| Favoritos | `favorite_food.user_id = sub` y `food` visible |
| Comidas para copiar | `diary_entry.user_id = sub` |
| Copia | lee y escribe solo entradas con `user_id = sub` |
| Deshacer copia | `user_id = sub AND copy_id = :id` |

Un alimento ajeno da `404 FOOD_NOT_FOUND`; una copia ajena, `404 COPY_NOT_FOUND`. Los dos son
indistinguibles de «no existe».
