# Research: Selección dinámica del modelo de Gemini

Sin marcadores «NEEDS CLARIFICATION» pendientes. Las decisiones de valores (24 h, 3 min, 20 s,
orden por nombre, 429 → siguiente, memoria) vienen de las Clarifications de la spec.

## R1. Descubrir modelos

- **Decisión**: `GET {BASE_URL}?pageSize=1000` con la clave en `x-goog-api-key`; seguir
  `nextPageToken` hasta 3 páginas. Un modelo es candidato si su `supportedGenerationMethods`
  contiene `generateContent`. El nombre llega como `models/gemini-…`; se guarda sin el prefijo.
- **Razón**: es el mismo endpoint que ya usa `validate_key`; no cuesta cuota de generación.
- **Alternativas**: lista fija en el código (es el problema que se resuelve); `models.get` por
  modelo (una llamada por candidato, más lento).
- **Nota**: el listado no declara «admite imágenes». Se infiere por el nombre (R2); los `flash`
  actuales de Gemini son multimodales.

## R2. Filtro y orden sin preferencia

- **Decisión**:
  1. Se parte de nombres que empiezan por `gemini-` y contienen `flash`.
  2. Se descartan los que contienen `exp`, `tts`, `image`, `live`, `audio`, `embedding`,
     `robotics`, `computer-use`, `pro` o `ultra` (como palabra entre guiones).
  3. Grupo 0 = contiene `lite`; grupo 1 = el resto. Orden: grupo ascendente, versión descendente
     (`gemini-(\d+)(?:\.(\d+))?-flash`), después el nombre en orden inverso (desempata fechas y
     `preview`). Los alias sin versión (`gemini-flash-latest`) van al final de su grupo: apuntan a
     lo más nuevo pero cambian sin avisar.
- **Razón**: aplica la regla de la spec (FR-005) con pruebas deterministas sobre listados de ejemplo.
- **Alternativas**: lista blanca en el código (se vuelve a romper al salir un modelo); pedir a
  Google el precio (no lo expone).
- **Riesgo asumido**: un modelo nuevo con nombre fuera del patrón no se elegirá solo. La preferencia
  (R8) sirve de salida y no exige redespliegue.

## R3. Preferencia

- **Decisión**: la preferencia entra tal cual si el modelo está en el listado y admite
  `generateContent`; **no** pasa por el filtro de nombre (Erick puede fijar uno `pro`). Una entrada
  que no figura en el listado se ignora y se registra `ai_model_preference_ignored` con `user_id` y el nombre
  (una vez por listado, no por análisis). Si ninguna preferencia es válida, se continúa con el
  orden automático y el origen queda `fallback` (FR-004, US3.2).
- **Razón**: el operador decide qué modelos son gratuitos.

## R4. Caché y evitación

- **Decisión**: dos `dict` en el selector, con reloj inyectable (`time.monotonic`):
  - `_catalog[key_hash] = (fetched_at, [ModelInfo])`, TTL 24 h.
  - `_cooldown[(key_hash, model)] = until`, 3 min tras un 503.
  - `key_hash = sha256(raw_key)`; la clave en claro nunca es clave de diccionario ni se registra.
- **Un 429 no entra en evitación**: es un límite por cuenta/modelo con ventana propia; el spec solo
  fija la evitación para saturación (FR-009).
- **Candidatos en evitación**: se omiten salvo que no quede ningún otro; entonces se intentan
  igualmente (mejor intentar que fallar sin llamar).
- **Un solo vuelo**: un `asyncio.Lock` por `key_hash` alrededor del listado evita dos peticiones
  simultáneas con caché vacía.
- **Poda**: al guardar la caché se eliminan entradas caducadas hace más de 24 h. Al borrar la clave
  (`delete_key`) se olvida su entrada. Con ≤ 50 usuarios no hace falta más.
- **Alternativas**: tabla en PostgreSQL o Redis (descartadas en Clarifications y por el
  principio VII).

## R5. Bucle de intentos y presupuesto

- **Decisión**: `deadline = now + AI_TIMEOUT_S`. Para cada candidato:
  `timeout = min(20, deadline - now)`; si queda menos de 1 s se corta. El listado usa
  `min(10, deadline - now)`.
- **Qué hace cada resultado**:

  | Resultado del candidato | Acción |
  |---|---|
  | 200 | devolver texto (`parse_response` valida después, en el servicio) |
  | 404 (`AiModelNotFound`) | quitarlo del catálogo; refrescar el listado **una vez** por análisis y recalcular candidatos |
  | 503 / red (`AiProviderUnavailable`) | 503 → evitación 3 min; siguiente |
  | 429 (`AiQuotaExceeded`) | siguiente |
  | tiempo agotado (`AiTimeout`) | siguiente |
  | 401/403/400 (`AiKeyInvalid`) | detener: la clave no sirve para ningún modelo |

- **Error final** cuando se agotan los candidatos: gana el más informativo: cuota (429) > tiempo
  agotado > proveedor no disponible. Sin candidatos desde el principio: `AiNoModelAvailable`.
- **Respuesta inválida**: no se reintenta con otro modelo. Es el comportamiento de la 006 (FR-013) y
  evita multiplicar coste y latencia; se registra el modelo que la produjo.
- **Riesgo asumido**: Google responde 400 tanto a clave mal escrita como a petición mal formada; el
  código actual ya lo trata como clave inválida. Con candidatos filtrados por `generateContent` un
  400 distinto de la clave es improbable, y mantener la regla evita cambiar el aviso de la 006.

## R6. Listado no disponible

- **Decisión**: fallo al listar (red, tiempo, 5xx) → usar el último catálogo de esa clave aunque haya
  caducado; sin catálogo → intentar las entradas de la preferencia tal cual, sin validar; sin
  preferencia → `AiProviderUnavailable`. Un fallo de listado no se cachea.
- **Razón**: coincide con el edge case de la spec y no crea un fallo nuevo en el camino de la foto.
- Un `401/403/400` al listar es `AiKeyInvalid`.

## R7. Interfaz del proveedor

- **Decisión**: `AiProvider.list_models(raw_key, timeout_s) -> list[ModelInfo]` y
  `analyze_photo(raw_key, model, image, prompt, timeout_s) -> str`. `GeminiProvider()` pierde sus
  argumentos de constructor. El selector es independiente del proveedor concreto.
- **Alternativa**: que el selector construya `GeminiProvider` por modelo (acopla el selector a Gemini
  y rompe el principio III).

## R8. Configuración

- **Decisión**: `AI_MODEL` se mantiene como nombre de variable y acepta una lista separada por
  comas (`gemini-3.6-flash-lite,gemini-3.6-flash`). Valor por defecto vacío = sin preferencia. Un
  valor ya configurado hoy sigue funcionando como primer elemento (spec, Assumptions).
  `Settings.ai_model_preference` devuelve la lista limpia. El valor por defecto `gemini-3.6-flash`
  del código desaparece.
- **Alternativa**: variable nueva `AI_MODELS` (obliga a migrar el despliegue sin ventaja).

## R9. Registro

- **Decisión**:
  - Por intento fallido: `ai_model_attempt` (warning) con `user_id`, `model`, `category` y `status` si lo hay.
  - Por fallo al obtener el listado: `ai_model_list_failed` (warning) con `user_id`, `category` y `status` si lo hay.
  - Todo evento de la feature lleva `user_id` (principio X: «usuario, resultado y causa del fallo»). El selector lo recibe como parámetro de `run`; no se usa estado global.
    Categorías: `model_not_found`, `overloaded`, `quota`, `timeout`, `network`, `key_invalid`.
  - Resultado: `ai_analysis` añade `model`, `selection` (`preferred` | `fallback`) y `attempts`
    (número de intentos). `model` es el último usado, incluso si falló.
  - El registro del proveedor sigue siendo solo código HTTP y `error.status` de Google (ya hecho en
    `_google_status`); nunca el cuerpo ni el mensaje.
- **Razón**: SC-005 (identificar la categoría en < 1 min) y SC-006.

## R10. Aviso «sin modelo»

- **Decisión**: nuevo `ErrorCode.AI_NO_MODEL_AVAILABLE`, HTTP 503, mensaje «No hay ningún modelo de
  IA disponible para tu clave. Puedes continuar a mano.». Se registra como `no_model`.
- **Por qué no reutilizar `AI_PROVIDER_UNAVAILABLE`**: FR-014 pide un aviso específico y el operador
  necesita distinguirlo en el registro. La app trata un código 503 desconocido como fallo
  genérico del análisis y deja el borrador (principio I); se comprueba en las tareas con una prueba
  de la app.
