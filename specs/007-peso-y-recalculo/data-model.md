# Data Model: Peso y recálculo del objetivo (Phase 1)

Reglas de acceso (todas las entidades): datos de salud → endpoints con `require_consent`; todo filtra
por el usuario autenticado (`sub` → `user_account.id`); un usuario solo ve y modifica lo suyo
(principios IV y V; FR-010).

## Entidad: Registro de peso — `weight_entry` (reutilizada de 002)

Ya existe (migración `0002`, `profile/models.py`). Esta feature la usa para el CRUD y la gráfica; no
cambia su esquema.

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | UUID | PK, `gen_random_uuid()` |
| `user_id` | UUID | FK `user_account.id` |
| `measured_on` | date | fecha del registro; único por `(user_id, measured_on)` |
| `weight_kg` | Numeric(4,1) | check 30–300; 1 decimal |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | se actualiza al editar |

- **Único por día** (`uq_weight_entry_user_day`): un segundo peso para el mismo día sustituye al
  anterior (US1.2) vía `upsert`.
- **Rango** (`ck_weight_range`): fuera de 30–300 → `400 VALIDATION_ERROR` (US1.5).
- **Fecha**: no futura (validación de la app por fecha local) + margen de 1 día en el backend
  (`research R2`); fuera de rango → `400 VALIDATION_ERROR` (US1.6).

Índice recomendado (añadir en `0006` si no existe): `ix_weight_entry_user_date (user_id,
measured_on)` para las consultas de la gráfica y la ventana de 7 días.

## Entidad: Media semanal (derivada, no se persiste)

Valor calculado por `weight/average.py` a partir de `weight_entry`. No es una tabla.

- **Ventana**: registros con `measured_on ∈ [as_of − 6d, as_of]` (7 días incluido `as_of`).
- **Valor**: media de esos `weight_kg`, redondeada a 1 decimal `ROUND_HALF_UP`.
- **Validez para recálculo**: solo con ≥3 registros en la ventana; si no, `None`.
- **Serie de gráfica**: por cada día con registro, media móvil de su ventana solo si ≥3 registros.

## Entidad: Propuesta de recálculo — `recalc_proposal` (NUEVA)

Persiste la propuesta y su respuesta (FR-007). Migración `0006`.

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | UUID | PK, `gen_random_uuid()` |
| `user_id` | UUID | FK `user_account.id` |
| `status` | text | `pending` \| `accepted` \| `ignored` (check) |
| `reference_weight_kg` | Numeric(4,1) | peso usado en el último cálculo (= `calc_weight_kg` vigente al crear) |
| `weekly_average_kg` | Numeric(4,1) | media semanal que disparó la propuesta (se actualiza mientras `pending`) |
| `target_from_id` | UUID | FK `daily_target.id`: objetivo vigente al proponer |
| `was_manual` | boolean | el objetivo vigente estaba editado a mano (aviso FR-008) |
| `created_at` | timestamptz | |
| `responded_at` | timestamptz \| null | al aceptar o ignorar |
| `ignored_until` | date \| null | solo al ignorar: `hoy + 7 días` |

**Restricciones**:
- `ck_recalc_status`: `status IN ('pending','accepted','ignored')`.
- `ck_recalc_responded`: `responded_at IS NULL = (status = 'pending')` (pendiente ⇔ sin responder).
- `ck_recalc_ignored_until`: `ignored_until IS NULL OR status = 'ignored'`.
- **Único índice parcial** `uq_recalc_pending (user_id) WHERE status = 'pending'`: a lo sumo una
  propuesta pendiente por usuario (una propuesta viva que se reusa/actualiza).
- Índice `ix_recalc_user_created (user_id, created_at)` para hallar la última respuesta/ignore.

**Estados**:

```text
(sin fila pendiente) --umbral superado, sin ignore vigente--> pending
pending --guardar/abrir con datos nuevos--> pending (actualiza weekly_average_kg y valores propuestos)
pending --aceptar--> accepted (recalcula objetivo; responded_at)
pending --ignorar--> ignored (responded_at; ignored_until = hoy+7)
ignored --pasa ignored_until y sigue el umbral--> (nueva fila) pending
```

Nota: la propuesta no guarda los valores del objetivo nuevo; se calculan de forma determinista desde
`reference`/`weekly_average_kg` y el perfil vigente al mostrarla y al aceptarla (reutiliza
`targets/calc.py`), evitando datos obsoletos.

## Entidad: Objetivo diario — `daily_target` (de 002, reutilizada)

Sin cambios de esquema. Campos relevantes aquí:

- `calc_weight_kg`: **peso usado en el cálculo** = referencia del umbral del 2% (FR-008).
- `source` (`calculated` | `manual`): `manual` ⇒ `was_manual = true` en la propuesta.
- `is_current` / `effective_from` / `superseded_at`: versionado; aceptar crea una versión nueva con
  `effective_from = ahora` (rige desde hoy; los días pasados conservan su objetivo, `research R8`).

## Diagrama de relaciones

```text
user_account 1───∞ weight_entry        (registros de peso, uno por día)
user_account 1───∞ daily_target        (versiones del objetivo; una vigente)
user_account 1───∞ recalc_proposal     (propuestas; ≤1 pending)
recalc_proposal ∞───1 daily_target     (target_from_id = objetivo al proponer)
```
