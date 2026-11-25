# UI Flows: 006 — Clave de IA y registro por foto

## Pantalla 1: Guía de la clave de IA (`AiKeyGuideScreen`)

**Acceso**: último paso del onboarding (opcional), fila de ajustes, opción de foto desactivada.

### Estado: sin clave

1. Título: «Clave de IA».
2. Pasos numerados para obtener la clave de Gemini:
   - «1. Entra en aistudio.google.com»
   - «2. Accede con tu cuenta de Google»
   - «3. Pulsa "Obtener clave de API" y crea una»
   - «4. Copia la clave y pégala aquí»
3. Campo de texto: «Pega tu clave aquí» (oscurecido como contraseña).
4. Botón principal: «Guardar clave».
   - En progreso: indicador en el botón.
   - Éxito (`200`): navegación a ajustes o cierre del onboarding; aviso «Clave configurada».
   - `AI_KEY_INVALID`: mensaje bajo el campo «La clave no es válida. Comprueba que la has
     copiado bien y que tu proyecto de Google tiene la API de Gemini activa.»
   - `AI_PROVIDER_UNAVAILABLE`: aviso «No se ha podido comprobar la clave ahora. Inténtalo más
     tarde.»
5. Si viene del onboarding: botón secundario «Omitir» (salta sin clave).

### Estado: con clave

1. «Clave configurada» con la fecha (`configured_at` formateada).
2. Proveedor: «Google Gemini».
3. Botón: «Cambiar clave» → muestra el campo para pegar una nueva.
4. Botón destructivo: «Quitar clave» → diálogo de confirmación → `DELETE /v1/ai-key` → vuelve al
   estado sin clave.

### Accesibilidad

- Campo de la clave: `labelText` «Clave de API», `obscureText: true`.
- Pasos: `Semantics(label: "Paso 1: …")` para TalkBack.
- Botones: etiquetas completas.

---

## Pantalla 2: Ajustes (modifica `SettingsScreen`)

Se añade una fila entre «Fuentes de datos» y el separador:

```
[ ] Clave de IA
    Configurada · 25 nov 2026           >
```

o si no tiene clave:

```
[ ] Clave de IA
    No configurada                      >
```

- Toque → `AiKeyGuideScreen`.
- El subtítulo se obtiene de `GET /v1/ai-key` (200 → configurada con fecha; 404 → no configurada).

---

## Pantalla 3: Opción de foto en la comida (modifica `MealSection`)

En el menú de la comida (el `⋮` de la 005) o en la pantalla de añadir, se añade la opción de foto:

### Con clave

- Icono de cámara + «Registrar con foto». Toque → `PhotoAnalysisScreen`.

### Sin clave (FR-016)

- Icono de cámara desactivado + «Registrar con foto» en gris.
- Subtítulo: «Necesitas una clave de IA».
- Toque → `AiKeyGuideScreen`.
- El resto de opciones (búsqueda, escáner, recientes, favoritos) funcionan igual.

---

## Pantalla 4: Captura y envío (`PhotoCaptureScreen`)

Pantalla rápida: capturar, opcionalmente describir, enviar y volver al diario.

### Paso 1: Captura

1. Se abre `image_picker` (cámara).
   - Si el permiso de cámara se deniega: mensaje «La cámara es necesaria para analizar la foto de
     tu plato» + botón «Elegir de la galería».
2. Campos opcionales bajo la vista previa de la foto:
   - «Descripción» (texto libre, ≤ 500 caracteres). Placeholder: «Ej: arroz con pollo y ensalada».
   - «Gramos totales del plato» (numérico). Placeholder: «Opcional».
3. Botón: «Analizar».

### Paso 2: Envío en segundo plano (no bloqueante)

Al pulsar «Analizar»:
1. La app **vuelve al diario** inmediatamente.
2. En la comida elegida aparece un chip «Analizando…» con un indicador de progreso circular
   pequeño. El chip es informativo; el usuario puede seguir registrando otros alimentos por
   búsqueda, escáner, recientes o favoritos.
3. La petición HTTP a `POST /v1/photo-analysis` se ejecuta en segundo plano
   (`PendingAnalysisNotifier`).

### Paso 3a: Éxito (en segundo plano)

- El chip cambia a «Análisis listo ✓» (toque → `ProposalEditScreen`).
- Además, aparece un snackbar «Foto analizada — toca para revisar» con acción «Ver».
- La propuesta se guarda también en el almacenamiento local como borrador con `proposal_json`,
  por si el usuario no la abre en esta sesión.

### Paso 3b: Error (en segundo plano)

- El chip cambia a «Análisis fallido ✕» (toque → pantalla de detalle del error).
- La foto queda como borrador con la causa.
- Snackbar con el mensaje de error resumido (research R11):
  - `AI_KEY_INVALID`: «Tu clave de IA no es válida» + acción «Ajustes».
  - `AI_QUOTA_EXCEEDED`: «Límite de tu cuenta de Google alcanzado».
  - `AI_RESPONSE_INVALID`, `AI_UNRECOGNIZED`: «No se pudo analizar» + acción «Ver borrador».
  - `AI_TIMEOUT`: «El análisis tardó demasiado» + acción «Reintentar».
  - `AI_PROVIDER_UNAVAILABLE`: «El proveedor no responde».

### Paso 3c: App cerrada durante el análisis

- Si la app se cierra antes de que Gemini responda, la foto queda como borrador con
  `failure_code: "interrupted"` y el mensaje «El análisis se interrumpió. Puedes reintentar.»
- Al abrir la app, el borrador aparece en la pantalla de borradores.

---

## Pantalla 5: Edición de la propuesta (`ProposalEditScreen`)

Lista editable de los alimentos propuestos:

### Cada fila

```
  Arroz blanco cocido (IA)              ← ai_name
  → Arroz, blanco, cocido (CIQUAL)      ← matched_food.name
  150 g · 195 kcal                      ← ai_grams · kcal calculadas
  [Cambiar] [✕]
```

- **Emparejado** (`matched_food != null`): el nombre de la IA arriba (referencia), el de la base
  abajo (valor real), gramos y kcal.
  - Tocar la fila → hoja para cambiar gramos (reutiliza la hoja de cantidad de la 004 con la
    cantidad sugerida = `ai_grams`).
  - «Cambiar» → búsqueda de la 003 para sustituir el alimento de la base.
  - «✕» → quita el alimento de la propuesta.

- **No emparejado** (`matched_food == null`): fondo destacado.
  ```
  ⚠ Yogur griego con miel (IA)
    Sin equivalente en tu base
    120 g
    [Buscar] [Crear] [✕]
  ```
  - «Buscar» → búsqueda de la 003.
  - «Crear» → `CustomFoodFormScreen` de la 003 con el nombre prellenado.
  - «✕» → quitar.

- **Flagged** (gramos absurdos): icono de advertencia junto a los gramos.

### Acciones globales

- «Añadir alimento» → búsqueda de la 003 para añadir uno que la IA no detectó.
- Totales al pie: kcal, proteínas, hidratos, grasas (solo de los emparejados).
- Botón principal: «Guardar en {comida}».
  - **Desactivado** si queda algún alimento sin emparejar.
  - Toque → crea las entradas con `POST /v1/diary/entries` (una por alimento) → navega al diario
    con el día actualizado.
- Botón secundario: «Cancelar» → la foto queda como borrador (descartable después).

---

## Pantalla 6: Borradores (`DraftsScreen`)

Acceso: indicador en el diario cuando hay borradores (badge en un icono o fila).

### Lista

Cada borrador:
```
  📷 Desayuno · 25 nov 2026
  Clave no válida
  [Reintentar] [Añadir a mano] [Descartar]
```

- **Reintentar**: reabre `PhotoAnalysisScreen` con la foto y los datos del borrador.
- **Añadir a mano**: abre la búsqueda de la 003 para la comida y el día del borrador.
- **Descartar**: diálogo de confirmación → elimina el borrador y la foto local.
- Completar (guardar entradas o añadir a mano) → elimina el borrador.

### Vacío

«No tienes borradores.»

---

## Onboarding: paso de la clave (sin cambios en el servidor, research R13a)

El enum `Onboarding` del backend no cambia (`consent → profile → done`). En `AppGate`
(`app/lib/app.dart`), cuando el estado es `Onboarding.done` y la bandera local
`onboarding_ai_key_seen` (`shared_preferences`) es falsa, se muestra `AiKeyGuideScreen(onboarding:
true)` en vez de `HomeScreen`:
- Botón «Omitir» visible (US1 escenario 1). Al omitir: `onboarding_ai_key_seen = true` → `HomeScreen`.
- Si el usuario pega una clave válida y la guarda: `onboarding_ai_key_seen = true` → `HomeScreen`
  con la clave configurada.
- Un usuario que ya vio este paso (lo completó u omitió) no vuelve a verlo al abrir la app; solo
  lo accede después desde ajustes.

---

## Estados y transiciones

```
Sin clave ──PUT /v1/ai-key (válida)──▶ Con clave
Con clave ──DELETE /v1/ai-key──▶ Sin clave
Con clave ──PUT /v1/ai-key (nueva)──▶ Con clave (nueva fecha)

Con clave ──foto──▶ Pendiente ──éxito──▶ Propuesta ──guardar──▶ Guardado (entradas en el diario)
                              ──fallo──▶ Borrador
                                         Borrador ──reintentar──▶ Pendiente
                                         Borrador ──a mano──▶ búsqueda (entradas en el diario)
                                         Borrador ──descartar──▶ eliminado
```
