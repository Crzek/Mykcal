# Contratos: proveedor de IA, API y configuración

La API HTTP no cambia de rutas ni de formas. Solo hay un código de error nuevo.

## 1. API HTTP (`/v1/photo-analysis`)

Igual que en la 006. Añade un caso:

| HTTP | `ErrorCode` | Cuándo | Mensaje |
|------|-------------|--------|---------|
| 503 | `AI_NO_MODEL_AVAILABLE` | La clave no ve ningún modelo compatible (FR-014) | «No hay ningún modelo de IA disponible para tu clave. Puedes continuar a mano.» |

El resto (`AI_KEY_INVALID` 422, `AI_QUOTA_EXCEEDED` 429, `AI_PROVIDER_UNAVAILABLE` 503,
`AI_TIMEOUT` 504, `AI_RESPONSE_INVALID` 422, `AI_UNRECOGNIZED` 422) mantiene su significado. Qué
código sale cuando se agotan los candidatos: cuota > tiempo agotado > proveedor no disponible
(research R5).

`PUT /v1/ai-key` no cambia: valida listando modelos y no depende de ninguno (FR-010).

## 2. Interfaz `AiProvider` (backend)

```python
@dataclass(frozen=True)
class ModelInfo:
    name: str              # sin prefijo "models/"
    generate_content: bool

class AiProvider(ABC):
    async def validate_key(self, raw_key: str) -> None: ...            # sin cambios
    async def list_models(self, raw_key: str, timeout_s: float) -> list[ModelInfo]: ...
    async def analyze_photo(
        self, raw_key: str, model: str, image: bytes, prompt: str, timeout_s: float
    ) -> str: ...
```

Excepciones:

| Excepción | Origen en Gemini |
|-----------|------------------|
| `AiKeyInvalid` | 400, 401, 403 (también al listar) |
| `AiQuotaExceeded` | 429 |
| `AiModelNotFound` (**nueva**) | 404 al generar |
| `AiProviderUnavailable` | 5xx, red, cuerpo ilegible; el 503 se distingue por un atributo `overloaded=True` |
| `AiTimeout` | tiempo agotado |
| `AiNoModelAvailable` (**nueva**) | la lanza el selector, no el proveedor |

## 3. Selector (`ai/model_selector.py`)

```python
class ModelSelector:
    def __init__(self, provider: AiProvider, preference: list[str],
                 clock: Callable[[], float] = time.monotonic) -> None: ...

    async def run(self, user_id: uuid.UUID, raw_key: str, total_timeout_s: float,
                  attempt: Callable[[str, float], Awaitable[str]]) -> SelectionOutcome: ...

    def forget(self, raw_key: str) -> None: ...
```

- `attempt(model, timeout_s)` es el envoltorio del servicio sobre `provider.analyze_photo`.
- `SelectionOutcome`: `text`, `model`, `selection` (`preferred`/`fallback`), `attempts`.
- Constantes: `CATALOG_TTL_S = 86400`, `COOLDOWN_S = 180`, `PER_MODEL_TIMEOUT_S = 20`,
  `LIST_TIMEOUT_S = 10`.
- Las funciones puras `is_economic(name)` y `rank(models)` se prueban sin red.

## 4. Configuración

| Variable | Antes | Ahora |
|----------|-------|-------|
| `AI_MODEL` | modelo fijo, por defecto `gemini-3.6-flash` | **preferencia opcional**: lista separada por comas; vacía por defecto |
| `AI_TIMEOUT_S` | 55 (de 5 a 58) | igual; es el presupuesto total |

Ejemplo: `AI_MODEL=gemini-3.6-flash-lite,gemini-3.6-flash`.

## 5. Registro

| Evento | Nivel | Campos |
|--------|-------|--------|
| `ai_analysis` | info | `user_id`, `result`, `model`, `selection`, `attempts`, `duration_ms` |
| `ai_model_attempt` | warning | `user_id`, `model`, `category`, `status` (si hay) |
| `ai_model_list_failed` | warning | `user_id`, `category` (`timeout`, `network`, `overloaded`, `quota`, `key_invalid`), `status` (si hay) |
| `ai_model_preference_ignored` | warning | `user_id`, `model` |
| `ai_provider_error` | warning | `status`, `result` (estado de Google) o `error_class` |

`category` ∈ `model_not_found`, `overloaded`, `quota`, `timeout`, `network`, `key_invalid`.
`result` de `ai_analysis` añade `no_model`. Ningún evento contiene clave, hash de la clave, foto,
respuesta de la IA, descripción ni mensajes del proveedor (FR-012).
