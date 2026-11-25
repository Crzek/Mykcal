# Research: Clave de IA y registro por foto

No queda ningún «NEEDS CLARIFICATION»: las dudas de la spec se resolvieron al redactarla
(2026-11-22). Este documento fija las decisiones de diseño que se apoyan en lo ya construido por las
features 001–005.

## R1. Cifrado de la clave de IA

- **Decision**: cifrado simétrico AES-256-GCM con la librería `cryptography` (Fernet no, porque no
  permite auditar el algoritmo y GCM da integridad autenticada).
  - La clave maestra vive en la variable de entorno `AI_KEY_MASTER` (32 bytes, codificados en
    base64), añadida a Dokploy. Nunca en la base de datos (principio IV, FR-003).
  - Al cifrar se genera un nonce de 12 bytes aleatorio; se guarda `nonce ‖ ciphertext ‖ tag`
    codificado en base64 en la columna `encrypted_key` de `ai_key`.
  - Descifrar: se lee `AI_KEY_MASTER`, se separan nonce, ciphertext y tag, se descifra en memoria
    y se usa para la llamada a la IA. La clave descifrada nunca se guarda ni se registra.
- **Rationale**: AES-256-GCM es el estándar para cifrado autenticado, disponible en `cryptography`
  sin dependencias extra. Con ≤ 50 usuarios, una tabla aparte con una sola fila por usuario es más
  limpia que añadir la columna a `user_account` (separación de responsabilidades; la cuenta no sabe
  de IA).
- **Alternatives considered**: Fernet (wrapper opaco, no se puede auditar el algoritmo ni el
  tamaño del nonce); cifrado de columna de PostgreSQL (`pgcrypto`, ata al motor); guardar la clave
  en el móvil y enviarla en cada petición (la clave viaja en cada request; un log de cabeceras la
  expone).

## R2. Validación de la clave al guardarla

- **Decision**: al recibir la clave, el backend hace una petición mínima a la API de Gemini
  (`models/gemini-2.0-flash:generateContent` con un prompt trivial, `maxOutputTokens: 1`) y
  comprueba que la respuesta es 200. Si la API rechaza la clave (401/403), se devuelve
  `422 AI_KEY_INVALID`; si no responde (timeout, 5xx), se devuelve `503 AI_PROVIDER_UNAVAILABLE`.
- El modelo de validación (`gemini-2.0-flash`) se elige por rapidez y coste mínimo; el modelo de
  análisis puede ser otro (R6).
- **Rationale**: la spec exige comprobar que funciona antes de guardarla (US1 escenario 2). Un
  token de 1 cuesta < 0,001 € y detecta claves revocadas al momento.
- **Alternatives considered**: solo validar el formato de la cadena (no detecta claves revocadas ni
  de proyecto equivocado); no validar (el usuario no sabe si funciona hasta que analice una foto).

## R3. Ninguna respuesta ni pantalla muestra la clave

- **Decision**:
  - `GET /v1/ai-key` devuelve `{ has_key, provider, configured_at }` o `404` si no hay clave.
    Nunca la clave ni un trozo.
  - `PUT /v1/ai-key` recibe la clave, la valida (R2), la cifra (R1) y la guarda. Devuelve el
    mismo `{ has_key, provider, configured_at }`.
  - `DELETE /v1/ai-key` la borra. Devuelve `204`.
  - La app muestra «Clave configurada» con la fecha, nunca el valor.
  - `test_no_key_in_response` recorre todas las respuestas JSON de las tres rutas y comprueba que
    ningún valor contiene la cadena de la clave de prueba.
- **Rationale**: principio IV y FR-004. La prueba automática garantiza que un refactor no la filtre.
- **Alternatives considered**: devolver los últimos 4 caracteres (sigue siendo parte de la clave).

## R4. Interfaz de proveedor de IA

- **Decision**: protocolo (ABC) `AiProvider` en `mykcal/ai/provider.py`:
  ```
  class AiProvider(ABC):
      async def validate_key(self, raw_key: str) -> bool
      async def analyze_photo(self, raw_key: str, image: bytes, prompt: str) -> AiAnalysisResult
  ```
  `GeminiProvider` implementa ambas con `httpx`. Las pruebas usan `FakeProvider` con respuestas
  guardadas (principio VI, FR-019). Un segundo proveedor solo necesita otra implementación sin
  tocar nada más (principio III, FR-018).
- El proveedor se inyecta en `app.state.ai_provider` en `create_app`, igual que `oidc` y
  `off_transport`.
- **Rationale**: la spec y la constitución exigen aislamiento del proveedor. Un ABC es lo más
  simple sin framework de DI.
- **Alternatives considered**: función suelta (no cumple FR-018); patrón estrategia con registro
  dinámico (YAGNI con un solo proveedor en el MVP).

## R5. Comunicación con Gemini

- **Decision**: llamada REST directa con `httpx` a
  `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`, con la clave
  del usuario en el query param `key` (así lo exige la API de Gemini para claves de API). No se
  usa el SDK de Google porque es síncrono y pesado.
  - Modelo de análisis: `gemini-2.0-flash` (barato, rápido, multimodal). Se parametriza en
    `Settings.ai_model` para cambiarlo sin redesplegar.
  - La imagen se envía como `inlineData` en base64 (`image/jpeg`). Tamaño máximo aceptado: 4 MB
    (la app redimensiona antes de enviar).
  - Timeout de 55 s en el backend (el límite de 60 s de la spec menos 5 s de margen de red).
- **Rationale**: `httpx` ya es dependencia del proyecto (OFF client, OIDC). El SDK
  `google-generativeai` trae `grpcio` (~40 MB) y no soporta async nativo; `httpx` sí.
- **Alternatives considered**: SDK oficial (`google-generativeai`): pesado, síncrono; `aiohttp`:
  añade otra dependencia HTTP cuando ya tenemos `httpx`.

## R6. Prompt y formato de respuesta de la IA

- **Decision**: el prompt pide a Gemini que devuelva **solo** un JSON con la lista de alimentos:
  ```json
  {
    "items": [
      { "name": "Arroz blanco cocido", "grams": 150 },
      { "name": "Pechuga de pollo a la plancha", "grams": 120 }
    ]
  }
  ```
  - Si el usuario da una descripción, se añade al prompt. Si da gramos totales, se indica como
    pista para la estimación.
  - Se usa `response_mime_type: "application/json"` y `response_schema` de Gemini para forzar JSON
    estructurado (modo JSON nativo).
  - La respuesta se valida con un schema Pydantic (`AiAnalysisResult`). Si no es JSON válido o no
    cumple el schema: fallo → borrador (FR-007, FR-014).
  - Alimentos duplicados en la respuesta: se agrupan sumando los gramos (edge case de la spec).
  - Gramos absurdos (0 o > 2000): se marcan con `flagged: true` para revisión (edge case).
- **Rationale**: el modo JSON nativo de Gemini reduce drásticamente las respuestas inválidas. El
  schema de Pydantic es la misma herramienta que ya valida el resto de la API.
- **Alternatives considered**: pedir texto libre y parsearlo (frágil, inconsistente); pedir
  también kcal a la IA (contradice el principio II).

## R7. Emparejamiento con la base de alimentos

- **Decision**: por cada alimento propuesto por la IA:
  1. Se normaliza el nombre con `foods.text.normalize`.
  2. Se busca en la base con `foods.repository.search` (pg_trgm, `word_similarity`), restringido a
     los alimentos visibles para el usuario.
  3. Si la similitud del primer candidato ≥ 0.5 (el umbral que ya usa la búsqueda de la 003):
     emparejado. Se devuelve con `matched_food` y los valores nutricionales de la base.
  4. Si no: `matched_food = null`, marcado como no emparejado. El usuario debe resolverlo antes de
     guardar (FR-008, US2 escenario 4).
- Los valores nutricionales siempre salen de `matched_food` (principio II, FR-009).
- Si la IA propone «Pollo a la plancha» y la base tiene «Pechuga de pollo, asada», la similitud de
  trigrama lo captura. Con la base CIQUAL de 359 alimentos + los personalizados, el umbral de 0.5
  da un buen balance entre falsos positivos y falsos negativos (SC-006: ≥ 70 %).
- **Rationale**: reutiliza la infraestructura de búsqueda de la 003 sin añadir nada. Buscar una
  vez por alimento propuesto (típicamente 3–8) es < 50 ms en total.
- **Alternatives considered**: embeddings vectoriales (YAGNI: 50 usuarios, 359 alimentos); pedir
  a la IA los códigos CIQUAL (alucinaciones con códigos numéricos); coincidencia exacta (demasiado
  estricta con nombres ligeramente distintos).

## R8. Flujo de estados del análisis (no bloqueante)

- **Decision**: el análisis pasa por estos estados (FR-013):
  ```
  pendiente → propuesto → guardado
                        → borrador (si falla o el usuario cancela)
  ```
  - **pendiente**: la foto se envió al backend; el usuario **no queda bloqueado**. La app vuelve
    al diario con un indicador sutil (chip «Analizando…» en la comida elegida). El usuario puede
    seguir registrando alimentos por búsqueda, escáner, recientes o favoritos mientras espera.
    Esto es crítico porque la capa gratuita de Gemini puede tardar 10–30 s.
  - **propuesto**: la IA respondió y los alimentos se emparejaron. La app muestra una notificación
    (snackbar persistente o badge en la comida) «Análisis listo» y el usuario toca para abrir la
    propuesta.
  - **guardado**: el usuario confirmó; se crean las entradas con `diary.service.create_entry`.
  - **borrador**: la IA falló o el usuario cerró la app sin abrir la propuesta. La foto y los
    metadatos (comida, día, descripción, causa del fallo) quedan en el móvil.
  - En la app, un `PendingAnalysisNotifier` (Riverpod, `family` por comida+día) gestiona la
    petición HTTP en segundo plano. Si la app se cierra antes de que responda, queda como borrador
    con `failure_code: "interrupted"`.
  - No hay tabla de borradores en PostgreSQL: viven en el almacenamiento local del móvil
    (Assumptions de la spec). Un borrador se pierde al cambiar de móvil.
  - No hay cola de trabajos ni WebSockets en el servidor: la petición HTTP al backend sigue siendo
    síncrona (recibe foto, llama a Gemini, responde); la asincronía es solo en la app.
- **Rationale**: la capa gratuita de Gemini puede tardar considerablemente. Bloquear al usuario en
  una pantalla de progreso durante 30 s es inaceptable. Con el análisis en segundo plano, el
  usuario sigue usando la app y recibe el resultado cuando está listo. El servidor sigue siendo
  stateless (principio VII).
- **Alternatives considered**: WebSockets (complejidad innecesaria para ≤ 50 usuarios); cola de
  trabajos con polling (añade infraestructura, contradice principio VII); tabla `photo_analysis` en
  el servidor (requiere guardar la foto; contradice FR-012).

## R9. La foto no se guarda en el servidor (FR-012)

- **Decision**: la foto llega al endpoint `POST /v1/photo-analysis` como `multipart/form-data`
  (`UploadFile` de FastAPI). Se lee en memoria como `bytes`, se envía a Gemini y se descarta al
  devolver la respuesta. No se escribe en disco ni en base de datos.
  - `test_photo_not_stored` comprueba que el directorio temporal y la base de datos no contienen
    la foto después del análisis (SC-003).
  - Tamaño máximo: 4 MB. FastAPI rechaza archivos mayores con 413.
- **Rationale**: principio IV. «0 fotos guardadas en el servidor» (SC-003).
- **Alternatives considered**: guardar temporalmente en `/tmp` y borrar (un crash dejaría la foto);
  guardar en la tabla para reintentar (contradice FR-012).

## R10. Registro de uso de la IA (FR-017)

- **Decision**: cada llamada a Gemini se registra con `structlog`:
  ```python
  log.info("ai_analysis",
      user_id=str(user_id),
      result="success" | "key_invalid" | "quota_exceeded" | "invalid_response"
           | "unrecognized" | "timeout" | "provider_error",
      model=model_name,
      duration_ms=duration,
  )
  ```
  - El propio `result` (un enum fijo) ya nombra la causa; no se añade un campo de texto libre con
    el motivo, para no arrastrar nada de la respuesta de la IA a los registros.
  - Nunca se registra la foto, la respuesta de la IA, la clave ni la descripción del usuario.
  - `model` y `result` se añaden a la lista blanca `ALLOWED_FIELDS` de `backend/src/mykcal/logging.py`
    (`user_id` y `duration_ms` ya están); sin eso, `structlog` los descartaría en silencio.
  - Se amplía `test_logs_no_secrets` con los campos del evento `ai_analysis`.
- **Rationale**: principio X y FR-017. `structlog` ya está configurado en el proyecto.
- **Alternatives considered**: tabla `ai_usage_log` en PostgreSQL (es una métrica, no un dato que
  el usuario consulta; los logs de `structlog` se pueden agregar si hace falta).

## R11. Causas de fallo y mensajes (FR-014)

- **Decision**: la respuesta de `POST /v1/photo-analysis` distingue estos fallos:
  | Respuesta Gemini | Código HTTP | ErrorCode | Mensaje (español) |
  |---|---|---|---|
  | 401/403 | 422 | `AI_KEY_INVALID` | «Tu clave de IA no es válida. Revísala en ajustes.» |
  | 429 | 429 | `AI_QUOTA_EXCEEDED` | «Has alcanzado el límite de tu cuenta del proveedor.» |
  | JSON inválido / no cumple schema | 422 | `AI_RESPONSE_INVALID` | «El análisis no ha podido completarse. Puedes reintentar o continuar a mano.» |
  | `items` vacío | 422 | `AI_UNRECOGNIZED` | «No se ha reconocido ningún alimento en la foto. Puedes continuar a mano.» |
  | Timeout (> 55 s) | 504 | `AI_TIMEOUT` | «El análisis ha tardado demasiado. Puedes reintentar.» |
  | 5xx / error de red | 503 | `AI_PROVIDER_UNAVAILABLE` | «El proveedor de IA no responde. Inténtalo más tarde.» |
  - La app convierte cada código en un borrador con el mensaje correspondiente y la acción posible
    (ir a ajustes, reintentar, continuar a mano).
  - Estas 6 causas son errores que **el servidor** devuelve. Hay una séptima causa, puramente del
    lado de la app, que nunca llega al servidor: **sin conexión al enviar la foto** (edge case de
    la spec). La app la distingue capturando el error de conectividad (p. ej. `DioException` sin
    respuesta) antes de que la petición salga o mientras está en vuelo, y crea el borrador con
    `failure_code: "no_connection"` y el mensaje «Sin conexión. Se ha guardado como borrador.»,
    con la acción «Reintentar».
- **Rationale**: la spec exige que el mensaje nombre la causa (US3 escenarios 1–3). Un código por
  causa permite a la app decidir la acción sin parsear texto.
- **Alternatives considered**: un solo código genérico `AI_ERROR` (el usuario no sabe qué hacer).

## R12. Almacenamiento local de borradores (app)

- **Decision**: los borradores se guardan en el almacenamiento local del móvil con
  `shared_preferences` (ya es dependencia de la app) como JSON serializado. Cada borrador contiene:
  - `id` (UUID local), `meal`, `entry_date`, `description`, `total_grams`, `failure_reason`,
    `failure_code`, `photo_path` (ruta local de la foto), `created_at`.
  - También se guarda una propuesta pendiente (análisis completado pero no abierto ni guardado)
    como borrador especial con `failure_code: null` y un campo extra `proposal_json` con el
    `PhotoAnalysisResult` serializado, para no perder el resultado si la app se cierra.
  - No contiene la clave de IA ni la respuesta cruda de Gemini.
  - Lista máxima: 20 borradores (los más viejos se descartan). Con un uso realista son 2–3.
- Un borrador se elimina cuando el usuario lo completa (guarda las entradas), lo completa a mano o
  lo descarta explícitamente (US3 escenario 5).
- **Rationale**: la spec dice que los borradores viven en el móvil (Assumptions). `shared_preferences`
  evita añadir SQLite o Hive; con ≤ 20 items el rendimiento no es un problema. Guardar la propuesta
  pendiente permite que el usuario cierre la app y la retome sin repetir el análisis.
- **Alternatives considered**: SQLite local (YAGNI: 20 registros JSON); Hive (dependencia nueva);
  no guardarlos (el usuario pierde la comida).

## R13a. Integración del paso de la clave en el onboarding (sin tocar el servidor)

- **Decision**: el enum `Onboarding` del backend (`consent → profile → done`) no cambia: añadir un
  estado de servidor para un paso opcional contradice el principio VII. En su lugar:
  - La app guarda localmente (`shared_preferences`, clave `onboarding_ai_key_seen`) si ya mostró el
    paso de la clave.
  - En `AppGate` (`app/lib/app.dart`), cuando `Onboarding.done` y `onboarding_ai_key_seen` es falso,
    se muestra `AiKeyGuideScreen(onboarding: true)` en vez de `HomeScreen`. Al guardar una clave o
    pulsar «Omitir», se marca `onboarding_ai_key_seen = true` y se navega a `HomeScreen`.
  - Un usuario que ya pasó por ahí (o que se registró antes de la 006) nunca vuelve a verlo al
    abrir la app; solo lo accede después desde ajustes.
- **Rationale**: ningún dato de servidor nuevo, ningún cambio a `/v1/me` ni a `Onboarding`. El
  paso es puramente una pantalla intermedia del lado de la app.
- **Alternatives considered**: nuevo valor de `Onboarding` en el backend (migración y cambio de
  contrato para un paso que ni siquiera es obligatorio); mostrarlo siempre en `done` sin bandera
  (molesta en cada apertura a quien ya decidió omitirlo).

## R13. Pantallas nuevas y modificadas

- **Decision**:
  - **Nueva**: pantalla de guía de la clave de IA (pasos para obtenerla, campo para pegarla,
    botón de guardar). Se abre desde: último paso del onboarding (opcional, se puede omitir),
    ajustes y la opción de foto desactivada.
  - **Nueva**: pantalla de análisis de foto (cámara/galería → progreso → propuesta → confirmar).
  - **Modificada**: `SettingsScreen` gana la fila «Clave de IA» con el estado (configurada/no) y
    la fecha.
  - **Modificada**: `MealSection` gana la opción de foto (activa con clave, desactivada sin ella).
  - **Modificada**: pantalla de añadir (la 004/005) gana la opción de foto junto a búsqueda y
    escáner.
  - **Nueva**: pantalla de borradores, accesible desde el diario cuando hay borradores.
  - **Nueva**: pantalla de edición de propuesta (lista editable de alimentos con gramos, búsqueda
    para sustituir o añadir, crear personalizado).
  - Detalle en `contracts/ui-flows.md`.
- **Rationale**: la guía de la clave es un flujo independiente que se reutiliza en tres sitios. El
  análisis es una pantalla nueva porque su flujo (progreso → propuesta → corrección → confirmar) no
  existe.

## R14. Permiso de cámara

- **Decision**: se usa el paquete `image_picker` (ya es dependencia de Flutter para la galería). Al
  pulsar el botón de foto:
  1. Si el permiso de cámara no está concedido, `image_picker` lo solicita.
  2. Si se deniega, se muestra un mensaje explicando por qué se necesita y se ofrece elegir de la
     galería (edge case de la spec).
  3. La foto se redimensiona a un máximo de 1024 px en el lado mayor y se comprime a JPEG ~80 %
     antes de enviarla (< 4 MB).
- **Rationale**: `image_picker` maneja cámara y galería con un solo paquete y ya gestiona los
  permisos nativos. Redimensionar evita subir fotos de 10 MB que Gemini procesa igual.
- **Alternatives considered**: `camera` (más control pero más código; no necesitamos vista previa
  personalizada); `permission_handler` aparte (duplica lo que `image_picker` ya hace).

## R15. Creación de alimento personalizado desde la propuesta

- **Decision**: si un alimento propuesto no tiene pareja en la base, el usuario puede:
  1. Buscar uno parecido (reutiliza la búsqueda de la 003).
  2. Crear un alimento personalizado con los datos que tiene (nombre y gramos). Reutiliza
     `POST /v1/foods/custom` de la 003. Los valores nutricionales los pone el usuario (obligatorio
     kcal, proteínas, hidratos y grasas).
  3. Quitarlo de la propuesta.
  - No puede guardar la propuesta con alimentos sin pareja (FR-008, US2 escenario 4).
- **Rationale**: reutiliza la creación de personalizados de la 003 y la búsqueda. No se inventa
  ningún flujo nuevo.

## R16. Dependencias nuevas

- **Backend**: `cryptography` (cifrado AES-256-GCM). Nada más; `httpx` y `pydantic` ya están.
- **App**: `image_picker` (si no está ya). `shared_preferences` ya es dependencia.
  - Verificación: comprobar si `image_picker` ya existe en `pubspec.yaml`.
