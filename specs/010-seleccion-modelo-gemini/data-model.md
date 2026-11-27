# Data Model: Selección dinámica del modelo de Gemini

No hay tablas, columnas ni migraciones. Todo vive en memoria del proceso o en el registro.

## ModelInfo (en memoria)

| Campo | Tipo | Notas |
|-------|------|-------|
| `name` | str | Sin el prefijo `models/`, p. ej. `gemini-3.6-flash` |
| `generate_content` | bool | `generateContent` figura en `supportedGenerationMethods` |

Solo se guardan los modelos con `generate_content = True`.

## Catálogo en caché

`_catalog: dict[key_hash, CatalogEntry]`

| Campo | Tipo | Regla |
|-------|------|-------|
| `fetched_at` | float (monotónico) | Caduca a las 24 h (FR-007) |
| `models` | list[ModelInfo] | Se quita el modelo que da 404 |

- `key_hash` = `sha256(raw_key).hexdigest()`. Nunca la clave en claro (FR-008).
- Se refresca si caduca o si un modelo da 404 (una vez por análisis).
- Si el refresco falla, se mantiene la entrada vieja y se sigue usando (R6).
- Se elimina al borrar la clave del usuario. Se pierde al reiniciar.

## Modelos evitados

`_cooldown: dict[(key_hash, model), until]`

- Se crea tras un 503; `until = now + 180 s` (FR-009).
- Se consulta al ordenar candidatos: un modelo en evitación pasa a ser candidato solo si no queda
  otro.
- Se limpia al caducar.

## Preferencia (configuración)

`Settings.ai_model` (`AI_MODEL`): texto, vacío por defecto. `ai_model_preference` = entradas
separadas por comas, sin espacios ni duplicados, en orden. No es un dato de la persona.

## Resultado de elección (solo registro)

| Campo | Valores |
|-------|---------|
| `model` | nombre del último modelo usado |
| `selection` | `preferred` si es de la preferencia; `fallback` en otro caso |
| `attempts` | nº de intentos (≥ 1) |
| cada intento fallido | `model`, `category`, `status` (opcional) |

Transiciones de un candidato en un análisis: `pendiente → usado` · `pendiente → descartado (404)` ·
`pendiente → evitado (503)` · `pendiente → saltado (429 / tiempo)`.
