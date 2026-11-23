# Data Model: 002 — Onboarding, objetivo diario y baja

PostgreSQL 16. La migración Alembic `0002_onboarding` crea cuatro tablas. Todas las fechas y horas
se guardan en `timestamptz` (UTC), salvo `measured_on`, que es una fecha local del usuario
(research R6). Todas las tablas nuevas tienen `user_id` y todo acceso se filtra por la cuenta
autenticada (principio V).

## health_consent

Entidad «Consentimiento» de la spec (FR-001–FR-003, research R8).

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `user_id` | `uuid` NOT NULL FK → `user_account.id` | |
| `text_version` | `text` NOT NULL | Igual a `CURRENT_CONSENT_VERSION` al insertar; 1–32 caracteres |
| `accepted_at` | `timestamptz` NOT NULL | Hora del servidor |

- `UNIQUE (user_id, text_version)`: aceptar dos veces la misma versión no crea otra fila.
- **Tiene consentimiento** ⇔ existe al menos una fila del usuario (en el MVP vale cualquier
  versión).
- Nunca se borra.

## user_profile

Entidad «Perfil». Una fila por usuario.

| Columna | Tipo | Reglas |
|---|---|---|
| `user_id` | `uuid` PK FK → `user_account.id` | |
| `age` | `smallint` NOT NULL | `CHECK (age BETWEEN 18 AND 100)` |
| `sex` | `text` NOT NULL | `CHECK (sex IN ('male','female'))` |
| `height_cm` | `smallint` NOT NULL | `CHECK (height_cm BETWEEN 100 AND 250)` |
| `activity_level` | `text` NOT NULL | `CHECK IN ('sedentary','light','moderate','high','very_high')` |
| `goal` | `text` NOT NULL | `CHECK IN ('lose_fat','maintain','gain_muscle')` |
| `created_at` | `timestamptz` NOT NULL | |
| `updated_at` | `timestamptz` NOT NULL | |

- Solo se puede insertar si el usuario tiene consentimiento (comprobado en la ruta, R9).
- El peso **no** está aquí (research R6).

### Niveles de actividad (FR-005)

| Código | Texto en la app | Factor |
|---|---|---|
| `sedentary` | Sedentario | 1,2 |
| `light` | Ligera: 1–3 días/semana | 1,375 |
| `moderate` | Moderada: 3–5 días/semana | 1,55 |
| `high` | Alta: 6–7 días/semana | 1,725 |
| `very_high` | Muy alta: trabajo físico o dos sesiones al día | 1,9 |

### Objetivos físicos (FR-009, FR-010)

| Código | Texto en la app | Factor kcal | Proteína |
|---|---|---|---|
| `lose_fat` | Perder grasa | 0,80 | 2,2 g/kg |
| `maintain` | Mantener | 1,00 | 1,8 g/kg |
| `gain_muscle` | Ganar músculo | 1,10 | 2,0 g/kg |

## weight_entry

Entidad «Registro de peso». La crea esta feature; la 007 la amplía con su propia pantalla.

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | `uuid` PK | |
| `user_id` | `uuid` NOT NULL FK → `user_account.id` | |
| `measured_on` | `date` NOT NULL | Fecha local enviada por la app; como máximo hoy + 1 día (UTC del servidor) |
| `weight_kg` | `numeric(4,1)` NOT NULL | `CHECK (weight_kg BETWEEN 30 AND 300)` |
| `created_at` | `timestamptz` NOT NULL | |
| `updated_at` | `timestamptz` NOT NULL | |

- `UNIQUE (user_id, measured_on)`: un registro por día. Guardar otro peso el mismo día lo
  sustituye (`INSERT … ON CONFLICT DO UPDATE`).
- **Peso actual** = el registro con mayor `measured_on` del usuario.

## daily_target

Entidad «Objetivo diario». Historial de versiones (research R4).

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | `uuid` PK | |
| `user_id` | `uuid` NOT NULL FK → `user_account.id` | |
| `is_current` | `boolean` NOT NULL | Índice único parcial `(user_id) WHERE is_current` |
| `effective_from` | `timestamptz` NOT NULL | Momento en que pasa a ser la vigente |
| `superseded_at` | `timestamptz` NULL | No es nulo ⇔ `is_current = false` (CHECK) |
| `source` | `text` NOT NULL | `CHECK IN ('calculated','manual')` |
| `kcal` | `integer` NOT NULL | 1–10.000 |
| `protein_g` | `integer` NOT NULL | 0–1.000 |
| `carbs_g` | `integer` NOT NULL | 0–2.000 |
| `fat_g` | `integer` NOT NULL | 0–1.000 |
| `fiber_g` | `integer` NOT NULL | 0–200 |
| `sodium_mg` | `integer` NOT NULL | 0–20.000 |
| `potassium_mg` | `integer` NOT NULL | 0–20.000 |
| `calcium_mg` | `integer` NOT NULL | 0–10.000 |
| `iron_mg` | `integer` NOT NULL | 0–200 |
| `magnesium_mg` | `integer` NOT NULL | 0–5.000 |
| `vitamin_d_ug` | `integer` NOT NULL | 0–500 |
| `vitamin_c_mg` | `integer` NOT NULL | 0–5.000 |
| `calc_weight_kg` | `numeric(4,1)` NOT NULL | Peso usado en el cálculo (FR-006, FR-013) |
| `calc_age` | `smallint` NOT NULL | |
| `calc_sex` | `text` NOT NULL | |
| `calc_height_cm` | `smallint` NOT NULL | |
| `calc_activity` | `text` NOT NULL | |
| `calc_goal` | `text` NOT NULL | |
| `calculated_at` | `timestamptz` NOT NULL | Fecha del cálculo |
| `calc_notices` | `text[]` NOT NULL | `{}` por defecto; `MIN_KCAL_APPLIED`, `CARBS_CLAMPED` (R3) |

- Los rangos son de saneamiento (R13), no reglas nutricionales.
- Todos los valores nutricionales son enteros: ya redondeados (FR-012).
- Índice `ix_daily_target_user_effective (user_id, effective_from)` para que la 004 busque el
  objetivo vigente en un día.

### Transiciones

```text
(sin objetivo) ──PUT /v1/profile (primera vez)──────────► calculated
calculated ──PUT /v1/profile con cambios──────────────────► calculated (nueva versión, automática)
calculated ──PUT /v1/target───────────────────────────────► manual
manual ─────PUT /v1/target────────────────────────────────► manual (nueva versión)
manual ─────PUT /v1/profile con cambios───────────────────► manual (sin cambios; se devuelve propuesta)
manual / calculated ──POST /v1/target/recalculate─────────► calculated
```

Cada flecha inserta una fila nueva (`is_current = true`, `effective_from = now()`) y cierra la
anterior (`is_current = false`, `superseded_at = now()`) en la misma transacción. «Sin cambios» no
escribe nada.

- **Edición manual**: copia los `calc_*`, `calculated_at` y `calc_notices` de la versión anterior.
- **Cambio relevante para recalcular**: alguna diferencia entre los `calc_*` vigentes y los campos
  del perfil enviados, o un `weight_kg` enviado distinto del último registro previo (research R12).

## user_account (de 001): baja

| Transición | Disparador | Efecto |
|---|---|---|
| `active → disabled` | `POST /v1/me/deactivation` | `status='disabled'`, `disabled_at=now()`. Los datos se conservan. Sin vuelta atrás desde la app |

## Valores calculados (no se guardan)

### `CalcInputs` → `CalcResult` (función pura, research R1–R3)

```text
CalcInputs: sex, age, height_cm, weight_kg (Decimal, 1 decimal), activity_level, goal
CalcResult: bmr, tdee (Decimal sin redondear, para pruebas),
            kcal, protein_g, carbs_g, fat_g, fiber_g, 7 micros (enteros),
            notices
```

1. `bmr = 10·peso + 6,25·altura − 5·edad + (5 si hombre, −161 si mujer)`
2. `tdee = bmr · factor_actividad`
3. `kcal = tdee · factor_objetivo`; si `kcal < mínimo(sexo)` → `kcal = mínimo`, aviso
   `MIN_KCAL_APPLIED`
4. `proteína = g/kg(objetivo) · peso`
5. `grasa = 0,25 · kcal / 9`
6. `carbohidratos = (kcal − 4·proteína − 9·grasa) / 4`; si `< 0` → `0`, aviso `CARBS_CLAMPED`
7. Fibra y micros: tabla de FR-011 por sexo; hierro de mujer = 8 mg si `edad ≥ 51`, 18 mg si no
8. Redondeo `ROUND_HALF_UP` a la unidad de cada valor de salida

### Estado del onboarding (`Me.onboarding`, research R10)

| Valor | Condición |
|---|---|
| `consent` | Sin fila en `health_consent` |
| `profile` | Con consentimiento y sin `user_profile` o sin `daily_target` vigente |
| `done` | Con perfil y objetivo vigente |

### Reglas de acceso de las rutas nuevas

| Ruta | Sin cuenta | Desactivada | Sin consentimiento |
|---|---|---|---|
| `POST /v1/consent` | 403 `ACCOUNT_NOT_REGISTERED` | 403 `ACCOUNT_DISABLED` | permitido |
| `POST /v1/me/deactivation` | 403 `ACCOUNT_NOT_REGISTERED` | 403 `ACCOUNT_DISABLED` | permitido |
| `GET/PUT /v1/profile` | 403 `ACCOUNT_NOT_REGISTERED` | 403 `ACCOUNT_DISABLED` | 403 `CONSENT_REQUIRED` |
| `GET/PUT /v1/target`, `POST /v1/target/recalculate` | 403 `ACCOUNT_NOT_REGISTERED` | 403 `ACCOUNT_DISABLED` | 403 `CONSENT_REQUIRED` |

`GET /v1/profile` y `GET /v1/target` responden `404 PROFILE_NOT_FOUND` o `404 TARGET_NOT_FOUND` si
aún no existen.

## Estado en la app (no persistido)

- `Me.onboarding`: elige la pantalla en `AppGate`.
- **Borrador del perfil** (`ProfileDraftNotifier`): los valores escritos. Se conservan si falla la
  red al guardar (edge case «Sin conexión al guardar»). Solo en memoria.
- **Borrador de edición del objetivo** (`TargetEditNotifier`): los 12 valores y el aviso de macros
  calculado en vivo (R13).
