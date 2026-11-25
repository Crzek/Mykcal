# API Changes: 006 — Clave de IA y registro por foto

Cambios al `openapi.yaml` vivo de la 001. Versión resultante: **0.6.0** (nuevas rutas y schemas).

## Rutas nuevas

### `GET /v1/ai-key`

Estado de la clave de IA del usuario.

- **Auth**: `require_consent` (como el resto de datos de salud).
- **200**: `AiKeyStatus { has_key: true, provider: "gemini", configured_at: "2026-11-25T…" }`
- **404**: no tiene clave configurada.
  `ErrorBody { code: "AI_KEY_NOT_FOUND", message: "No tienes una clave de IA configurada." }`

### `PUT /v1/ai-key`

Guardar o sustituir la clave.

- **Auth**: `require_consent`.
- **Body**: `AiKeyCreate { raw_key: string }` (min 1, max 256 caracteres).
- **200**: `AiKeyStatus` (clave guardada con éxito).
- **422**: `ErrorBody { code: "AI_KEY_INVALID" }` — la clave no funciona con el proveedor.
- **503**: `ErrorBody { code: "AI_PROVIDER_UNAVAILABLE" }` — el proveedor no responde (no se puede
  validar).

### `DELETE /v1/ai-key`

Quitar la clave.

- **Auth**: `require_consent`.
- **204**: clave eliminada (idempotente: si no había clave, también `204`).

### `POST /v1/photo-analysis`

Analizar una foto de un plato.

- **Auth**: `require_consent`.
- **Content-Type**: `multipart/form-data`.
- **Campos**:
  | Nombre | Tipo | Requerido | Descripción |
  |---|---|---|---|
  | `photo` | `file` | Sí | JPEG, ≤ 4 MB |
  | `meal` | `string` | Sí | Una de: `breakfast`, `lunch`, `afternoon_snack`, `dinner`, `snacks` (mismo enum `Meal` de la 004) |
  | `entry_date` | `string (date)` | Sí | ISO 8601, misma validación que la 004 |
  | `description` | `string` | No | ≤ 500 caracteres |
  | `total_grams` | `integer` | No | ≥ 1 |

- **200**: `PhotoAnalysisResult { items: ProposedItem[] }`.
- **403**: `AI_KEY_REQUIRED` — sin clave configurada.
- **413**: foto demasiado grande (> 4 MB).
- **422**: `AI_KEY_INVALID` — clave revocada o inválida.
- **422**: `AI_RESPONSE_INVALID` — respuesta de la IA inválida.
- **422**: `AI_UNRECOGNIZED` — no se reconoció ningún alimento.
- **429**: `AI_QUOTA_EXCEEDED` — cuota del proveedor agotada.
  `Retry-After` si Gemini lo proporciona.
- **504**: `AI_TIMEOUT` — el análisis tardó más de 55 s.
- **503**: `AI_PROVIDER_UNAVAILABLE` — el proveedor no responde.

## Schemas nuevos

### `AiKeyStatus`

```yaml
AiKeyStatus:
  type: object
  required: [has_key, provider, configured_at]
  properties:
    has_key: { type: boolean, const: true }
    provider: { type: string, enum: [gemini] }
    configured_at: { type: string, format: date-time }
```

### `AiKeyCreate`

```yaml
AiKeyCreate:
  type: object
  required: [raw_key]
  properties:
    raw_key: { type: string, minLength: 1, maxLength: 256 }
```

### `PhotoAnalysisResult`

```yaml
PhotoAnalysisResult:
  type: object
  required: [items]
  properties:
    items:
      type: array
      items: { $ref: "#/components/schemas/ProposedItem" }
```

### `ProposedItem`

```yaml
ProposedItem:
  type: object
  required: [ai_name, ai_grams, flagged]
  properties:
    ai_name: { type: string }
    ai_grams: { type: number, format: decimal }
    flagged: { type: boolean }
    matched_food: { $ref: "#/components/schemas/FoodSummary", nullable: true }
    matched_similarity: { type: number, format: float, nullable: true }
    kcal: { type: number, format: decimal, nullable: true }
    protein_g: { type: number, format: decimal, nullable: true }
    carbs_g: { type: number, format: decimal, nullable: true }
    fat_g: { type: number, format: decimal, nullable: true }
```

## ErrorCodes nuevos

| Código | HTTP | Uso |
|---|---|---|
| `AI_KEY_NOT_FOUND` | 404 | `GET /v1/ai-key` sin clave |
| `AI_KEY_INVALID` | 422 | Clave no funciona con el proveedor |
| `AI_KEY_REQUIRED` | 403 | Análisis sin clave configurada |
| `AI_PROVIDER_UNAVAILABLE` | 503 | El proveedor no responde |
| `AI_QUOTA_EXCEEDED` | 429 | Cuota del proveedor agotada |
| `AI_RESPONSE_INVALID` | 422 | Respuesta de la IA inválida |
| `AI_UNRECOGNIZED` | 422 | No se reconoció ningún alimento |
| `AI_TIMEOUT` | 504 | Análisis tardó > 55 s |

## Rutas sin cambios en la 006

Las rutas existentes de la 004 y la 005 no cambian. `POST /v1/diary/entries` se reutiliza tal cual
para guardar los alimentos confirmados de la propuesta.

## Resumen de rutas públicas

No se añade ninguna ruta pública. Las 4 rutas nuevas exigen `require_consent`.
`PUBLIC_ROUTES` sigue siendo `{GET /v1/health, GET /descargar/mykcal.apk}`.
