# Implementation Plan: Clave de IA y registro por foto

**Branch**: `006-clave-ia-y-foto` | **Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-clave-ia-y-foto/spec.md`

## Summary

El usuario configura su clave personal de Gemini (guiado por la app, cifrada en el servidor), hace
una foto de un plato, la IA propone una lista de alimentos con gramos, el usuario corrige y guarda.
Los valores nutricionales salen siempre de la base de alimentos, nunca de la IA. Si el análisis
falla, la foto queda como borrador en el móvil.

- **Clave de IA**: tabla `ai_key` con cifrado AES-256-GCM. Rutas `GET/PUT/DELETE /v1/ai-key`.
  Validación contra Gemini antes de guardar. La clave nunca aparece en respuestas ni logs (R1–R3).
- **Interfaz de proveedor**: ABC `AiProvider` con `GeminiProvider` (httpx) y `FakeProvider` para
  pruebas. Permite añadir otros proveedores sin cambiar el sistema (R4).
- **Análisis de foto (no bloqueante)**: `POST /v1/photo-analysis` recibe la foto como multipart, la
  envía a Gemini, valida la respuesta JSON, empareja cada alimento con la base por trigrama
  (`search` de la 003) y devuelve la propuesta. La foto no se guarda (R5–R9). La app envía la
  petición en segundo plano y el usuario puede seguir usando la app mientras Gemini responde
  (la capa gratuita puede tardar 10–30 s). Cuando el resultado llega, se notifica al usuario (R8).
- **Propuesta editable**: la app muestra los alimentos emparejados con los valores de la base. El
  usuario corrige gramos, sustituye o quita alimentos, crea personalizados para los no emparejados
  y guarda con `POST /v1/diary/entries` de la 004 (R15).
- **Borradores**: almacenamiento local (`shared_preferences`) con foto, comida, día y causa del
  fallo. Reintentar, continuar a mano o descartar (R12).
- **Sin clave**: la opción de foto queda desactivada con acceso a la guía; el resto funciona (R13).
- **App**: guía de la clave (onboarding + ajustes), análisis, propuesta, borradores. Ajustes gana
  la fila de la clave. La comida gana la opción de foto (`contracts/ui-flows.md`).

## Technical Context

**Language/Version**: Python 3.12 (backend); Dart ≥ 3.5 / Flutter ≥ 3.32 (app). Sin cambios.

**Primary Dependencies**: las de la 005 más `cryptography` en el backend (R1). App: `image_picker`
(R14). Backend: `httpx` para Gemini (ya es dependencia).

**Storage**: PostgreSQL 16. La migración `0006_ai_key` crea la tabla `ai_key` (`data-model.md`). En
el móvil se añade el almacenamiento local de borradores con `shared_preferences`.

**Testing**:
- Backend: pytest.
  - Unitarias: `test_ai_crypto.py` (cifrar/descifrar), `test_ai_prompt.py` (construcción y
    validación), `test_ai_matching.py` (emparejamiento por trigrama).
  - Integración con testcontainers y `FakeProvider`: clave (guardar, sustituir, quitar, inválida),
    análisis (éxito, 7 tipos de fallo), foto no guardada.
  - Contrato contra `openapi.yaml` 0.6.0.
  - `privacy`: aislamiento, consentimiento, identidad, clave no en respuestas, foto no almacenada,
    logs sin secretos.
- App: flutter_test + mocktail. Guía de la clave, flujo de foto, propuesta, borradores, a11y.

**Target Platform**: Android API ≥ 24; contenedor Linux en Dokploy.

**Project Type**: móvil + API (monorepo `backend/` + `app/`).

**Performance Goals**:
- SC-001: registrar un plato con una corrección en < 1 minuto desde la cámara. El análisis de
  Gemini suele tardar 3–8 s; el emparejamiento < 50 ms; la corrección y el guardado son toques.
- SC-006: ≥ 70 % de emparejamiento automático correcto con 20 platos habituales. Se valida con
  las pruebas de emparejamiento y, en la validación manual, con fotos reales.

**Constraints**:
- Valores solo desde la base (principio II): `kcal` y macros de `matched_food`, nunca de Gemini.
- La clave cifrada con `AI_KEY_MASTER` (variable de entorno), nunca en la base en texto claro
  (principio IV).
- 0 fotos en el servidor (FR-012). 0 claves en respuestas ni logs (FR-004, principio X).
- Proveedor aislado detrás de ABC (principio III, FR-018).
- Pruebas con `FakeProvider`: sin claves reales ni llamadas a Gemini (principio VI, FR-019).
- Español, métrica, WCAG 2.1 AA (FR-020).
- Requiere conexión para el análisis. Sin ella, la foto queda como borrador.

**Scale/Scope**: 1 tabla nueva, 4 rutas nuevas, 8 error codes nuevos; 2 pantallas nuevas (guía,
borradores), 2 flujos nuevos (análisis, propuesta), 3 pantallas modificadas (ajustes, comida,
onboarding).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| I. La IA propone | ✅ | Nada se guarda sin la confirmación del usuario (FR-011). La propuesta es editable: el usuario corrige gramos, sustituye alimentos y confirma. Un borrador se queda en el móvil hasta que el usuario lo descarte. |
| II. Base de alimentos | ✅ | Los valores nutricionales salen de `matched_food` (la base), nunca de Gemini. La IA solo propone nombres y gramos; cada alimento se cruza con la base y, si no hay pareja, el usuario lo resuelve o lo quita (FR-008, FR-009). Guardar usa `create_entry` de la 004, que copia los valores del alimento. |
| III. IA opcional | ✅ | Sin clave la foto queda desactivada con acceso a la guía (FR-016). Búsqueda, escáner, recientes, favoritos y copiar funcionan sin ella. El proveedor está detrás de `AiProvider` para añadir otros (FR-018). |
| IV. Privacidad y salud | ✅ | La clave se cifra con AES-256-GCM y la clave maestra vive en variable de entorno (FR-003). Ninguna respuesta ni log contiene la clave (FR-004). La foto se procesa en memoria y se descarta; 0 fotos en el servidor (FR-012). Las 4 rutas exigen `require_consent`. Pruebas: `test_no_key_in_response`, `test_photo_not_stored`, `test_logs_no_secrets`. |
| V. Aislamiento y seguridad | ✅ | `ai_key.user_id = sub`. B no ve, sustituye ni borra la clave de A (`404 AI_KEY_NOT_FOUND`). El análisis usa la clave propia; sin clave → `403 AI_KEY_REQUIRED`. Las entradas guardadas se filtran por `user_id`. Prueba: `test_user_isolation_ai`. Ninguna ruta pública nueva. |
| VI. Determinista y sin servicios reales | ✅ | El emparejamiento (trigrama + umbral fijo) es determinista. Las pruebas usan `FakeProvider` con respuestas guardadas; ninguna llama a Gemini (FR-019). El cifrado se prueba con una clave maestra de prueba. |
| VII. Simplicidad | ✅ | Una tabla (`ai_key`), un ABC, un endpoint de análisis stateless. No hay cola de trabajos: la petición HTTP bloquea hasta la respuesta de Gemini (≤ 55 s). Los borradores en `shared_preferences` sin SQLite. `httpx` en vez del SDK pesado de Google (R5). |
| VIII. Accesible, español, métrica | ✅ | ARB, g/kcal, campos etiquetados, TalkBack en la guía, la propuesta y los borradores, 48 dp en áreas táctiles (`contracts/ui-flows.md`). |
| IX. Entrega vertical | ✅ | Usable en el móvil: configurar clave, hacer foto, corregir, guardar. Antes de fusionar: pruebas y escenarios contra el backend local con clave real. Se cierra tras desplegar desde `main` y repetir los escenarios 2, 6, 12, 14 y 20 (`quickstart.md` §6). |
| X. Observabilidad | ✅ | Evento `ai_analysis` con `user_id`, `result`, `model`, `duration_ms`, sin foto, respuesta ni clave (FR-017). Se amplía `test_logs_no_secrets` (SC-005). |
| Ramas y entornos | ✅ | La rama `006-clave-ia-y-foto` sale de `dev` con la 005 y volverá a `dev` por PR. |
| Flujo: preguntas abiertas resueltas | ✅ | No quedan preguntas abiertas. Las asunciones (Gemini como proveedor del MVP, borradores en el móvil) están en la spec. El modelo concreto (`gemini-2.0-flash`) se decidió en la investigación (R5). |

**Resultado**: pasa sin excepciones.

**Re-check tras el diseño (Phase 1)**: sin cambios.
- Las 4 rutas nuevas exigen autenticación, cuenta activa y consentimiento. Ninguna pública.
- `ai_key` guarda solo la clave cifrada y la fecha; no es dato de salud en sí, pero se protege con
  el mismo aislamiento y consentimiento.
- La migración `0006_ai_key` crea una tabla nueva sin modificar las existentes.
- `AI_KEY_MASTER` se valida al arrancar: sin ella el backend no arranca, evitando un deploy sin la
  variable.

## Project Structure

### Documentation (this feature)

```text
specs/006-clave-ia-y-foto/
├── plan.md
├── research.md              # R1–R16
├── data-model.md            # ai_key, análisis (stateless), borradores (local), acceso
├── quickstart.md            # pruebas, migración, variable y 27 escenarios
├── contracts/
│   ├── api-changes.md       # cambios al openapi.yaml vivo (0.6.0)
│   └── ui-flows.md          # pantallas, estados y mensajes
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── alembic/versions/0006_ai_key.py                 # nuevo
├── src/mykcal/
│   ├── main.py                                      # + router de ai, ai_provider en state
│   ├── config.py                                    # + ai_key_master, ai_model
│   ├── core/errors.py                               # + 8 error codes
│   ├── ai/                                          # nuevo
│   │   ├── provider.py                              # ABC AiProvider, AiAnalysisResult
│   │   ├── gemini.py                                # GeminiProvider (httpx)
│   │   ├── fake.py                                  # FakeProvider para pruebas
│   │   ├── crypto.py                                # encrypt_key, decrypt_key (AES-256-GCM)
│   │   ├── prompt.py                                # build_prompt, parse_response, merge_duplicates
│   │   ├── matching.py                              # match_items (usa foods.repository.search)
│   │   ├── models.py                                # AiKey
│   │   ├── schemas.py                               # AiKeyStatus, AiKeyCreate, PhotoAnalysisResult, ProposedItem
│   │   ├── repository.py                            # get_key, upsert_key, delete_key (siempre con user_id)
│   │   ├── service.py                               # validate_and_save_key, delete_key, analyze_photo
│   │   └── router.py                                # /v1/ai-key, /v1/photo-analysis
│   └── ...
└── tests/
    ├── conftest.py                                  # + FakeProvider, ai_key_master de prueba
    ├── unit/
    │   ├── test_ai_crypto.py                        # cifrar, descifrar, clave maestra distinta
    │   ├── test_ai_prompt.py                        # prompt, validación, duplicados, flagged
    │   └── test_ai_matching.py                      # emparejamiento con trigrama
    ├── integration/
    │   ├── test_ai_key.py                           # guardar, sustituir, quitar, inválida, proveedor caído
    │   └── test_photo_analysis.py                   # éxito + 7 fallos, foto no guardada
    ├── contract/test_ai_contract.py                 # contra openapi.yaml 0.6.0
    └── privacy/
        ├── test_no_key_in_response.py               # nuevo (FR-004, SC-003)
        ├── test_photo_not_stored.py                 # nuevo (FR-012, SC-003)
        ├── test_user_isolation_ai.py                # nuevo
        ├── test_consent_gate.py                     # + 4 rutas
        ├── test_all_routes_require_identity.py      # cubre las rutas nuevas
        └── test_logs_no_secrets.py                  # + evento ai_analysis (SC-005)

specs/001-acceso-y-despliegue/contracts/openapi.yaml   # 0.6.0: rutas y schemas de api-changes.md

app/
├── lib/
│   ├── core/api/
│   │   ├── models.dart                              # + AiKeyStatus, PhotoAnalysisResult, ProposedItem
│   │   └── mykcal_api.dart                          # + getAiKey, saveAiKey, deleteAiKey, analyzePhoto
│   ├── features/
│   │   ├── ai_key/                                  # nuevo
│   │   │   ├── ai_key_controller.dart               # AsyncNotifier: get, save, delete
│   │   │   └── ai_key_guide_screen.dart             # guía, campo y botón
│   │   ├── photo/                                   # nuevo
│   │   │   ├── photo_capture_screen.dart            # cámara/galería → descripción → enviar y volver
│   │   │   ├── pending_analysis_notifier.dart       # análisis en segundo plano (no bloqueante)
│   │   │   ├── analysis_chip.dart                   # chip «Analizando…» / «Listo ✓» en la comida
│   │   │   ├── proposal_edit_screen.dart            # lista editable, guardar
│   │   │   ├── proposed_item_tile.dart              # fila: nombre IA, nombre base, gramos, acciones
│   │   │   ├── drafts_screen.dart                   # lista de borradores
│   │   │   ├── drafts_controller.dart               # AsyncNotifier sobre shared_preferences
│   │   │   └── draft_model.dart                     # modelo serializable (+ proposal_json)
│   │   ├── diary/meal_section.dart                  # + onPhoto, aiKeyConfigured (icono cámara)
│   │   └── settings/settings_screen.dart            # + fila «Clave de IA»
│   ├── app.dart                                      # + paso de la clave tras onboarding (R13a)
│   └── l10n/app_es.arb                              # textos nuevos
└── test/
    ├── ai_key/ai_key_guide_test.dart
    ├── photo/photo_analysis_test.dart
    ├── photo/proposal_edit_test.dart
    └── photo/drafts_test.dart
```

**Structure Decision**: se mantiene el monorepo.
- **Backend**: paquete nuevo `ai` para todo lo de la clave y el análisis. El proveedor (`provider`,
  `gemini`, `fake`) está separado de la lógica de negocio (`service`, `matching`). Las funciones
  puras van en módulos aparte (`crypto`, `prompt`, `matching`), para probarlas sin base de datos ni
  red.
- **App**: carpeta `features/ai_key/` para la guía y el controlador de la clave. Carpeta
  `features/photo/` para el análisis, la propuesta y los borradores. La fila de ajustes y la opción
  de foto se integran en las pantallas existentes.

## Complexity Tracking

Sin violaciones que justificar.

## Decisiones tomadas

1. **Modelo de Gemini**: `gemini-2.0-flash`. Rapidez y coste mínimo (< 0,01 €/análisis). Se
   parametriza en `Settings.ai_model` para cambiarlo sin redesplegar si hace falta.
2. **Tamaño máximo de foto**: 4 MB. La app redimensiona a 1024 px y comprime a JPEG ~80 %; con
   fotos de móvil es < 1 MB.
3. **Máximo 20 borradores locales**: con un uso realista son 2–3; al llegar a 20 se descarta el
   más antiguo automáticamente.
4. **Paso de la clave en el onboarding**: no se añade un estado nuevo a `Onboarding` en el
   servidor (principio VII). La app muestra `AiKeyGuideScreen` una sola vez, client-side, cuando
   `Onboarding.done` y una bandera local (`shared_preferences`) indica que aún no se mostró (R13a).
   Se puede omitir. También accesible desde ajustes y desde la opción de foto desactivada.
5. **Análisis no bloqueante**: la capa gratuita de Gemini puede tardar 10–30 s. La app envía la
   foto en segundo plano, vuelve al diario con un chip «Analizando…» y el usuario sigue usando la
   app. Cuando el resultado llega, aparece «Análisis listo» y el usuario toca para revisar la
   propuesta. Si la app se cierra antes, queda como borrador recuperable.
