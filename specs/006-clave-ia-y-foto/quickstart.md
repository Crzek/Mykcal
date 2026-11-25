# Quickstart: validación de la 006

## 1. Pruebas automáticas

```bash
cd backend && uv run ruff check && uv run pytest
cd app && flutter analyze && flutter test
```

Todo en verde. En particular:

- `tests/unit/test_ai_crypto.py`: cifrar y descifrar con una clave maestra de prueba; descifrar con
  una clave maestra distinta falla; el resultado no contiene la clave original en texto claro.
- `tests/unit/test_ai_prompt.py`: construir el prompt con y sin descripción, con y sin gramos
  totales; validar respuestas válidas, inválidas, vacías y con duplicados (agrupados).
- `tests/unit/test_ai_matching.py`: emparejamiento de nombres propuestos con alimentos de la base;
  similitud ≥ 0.5 → emparejado, < 0.5 → `null`; gramos absurdos → `flagged`.
- `tests/integration/test_ai_key.py`:
  - `PUT` con clave válida (fake provider) → `200 AiKeyStatus`; `GET` → configurada con fecha;
    `DELETE` → `204`; `GET` → `404`.
  - `PUT` con clave inválida → `422 AI_KEY_INVALID`; `GET` → sigue sin clave.
  - `PUT` con proveedor caído → `503 AI_PROVIDER_UNAVAILABLE`.
  - Sustituir clave: `PUT` dos veces → la fecha se actualiza.
- `tests/integration/test_photo_analysis.py`:
  - Éxito: foto con fake provider → `200 PhotoAnalysisResult` con items emparejados.
  - Sin clave → `403 AI_KEY_REQUIRED`.
  - Clave revocada → `422 AI_KEY_INVALID`.
  - Cuota agotada → `429 AI_QUOTA_EXCEEDED`.
  - Respuesta inválida → `422 AI_RESPONSE_INVALID`.
  - Items vacíos → `422 AI_UNRECOGNIZED`.
  - Timeout → `504 AI_TIMEOUT`.
  - Proveedor caído → `503 AI_PROVIDER_UNAVAILABLE`.
  - Foto > 4 MB → `413`.
- `tests/privacy/test_no_key_in_response.py`: ninguna respuesta JSON de las rutas de `ai-key` ni
  de `photo-analysis` contiene la clave de prueba (SC-003, FR-004).
- `tests/privacy/test_photo_not_stored.py`: después del análisis, el directorio temporal y la base
  no contienen la foto (SC-003, FR-012).
- `tests/privacy/test_user_isolation_ai.py`: B no ve la clave de A (`GET` → `404`), no puede
  analizar con la clave de A, no puede borrar la clave de A.
- `tests/privacy/test_consent_gate.py`: + 4 rutas nuevas.
- `tests/privacy/test_all_routes_require_identity.py`: cubre las rutas nuevas.
- `tests/privacy/test_logs_no_secrets.py`: + evento `ai_analysis` sin foto, respuesta ni clave
  (SC-005).
- `tests/contract/test_ai_contract.py`: respuestas válidas contra `openapi.yaml` 0.6.0.
- App: `test/ai_key/ai_key_guide_test.dart`: guardar clave válida, inválida, omitir en onboarding.
  `test/photo/photo_analysis_test.dart`: flujo de propuesta, corrección y guardado.
  `test/photo/drafts_test.dart`: listar, reintentar, añadir a mano, descartar.
  `test/photo/proposal_edit_test.dart`: cambiar gramos, sustituir alimento, quitar, crear
  personalizado, guardar desactivado con no emparejados.

## 2. Migración en local

```bash
cd backend && docker compose -f docker-compose.dev.yml up -d
uv run alembic upgrade head        # aplica 0006_ai_key sobre 0005_quick
uv run alembic downgrade -1        # elimina ai_key
uv run alembic upgrade head
```

## 3. Variable de entorno

Generar la clave maestra de prueba:

```bash
python3 -c "import secrets, base64; print(base64.b64encode(secrets.token_bytes(32)).decode())"
```

Añadir a `.env` local: `AI_KEY_MASTER=<valor>`.

En Dokploy: añadir la variable `AI_KEY_MASTER` con un valor distinto al de desarrollo.

## 4. APK con backend local

```bash
cd backend && uv run uvicorn mykcal.main:create_app --factory --host 0.0.0.0
cd app && flutter run --flavor dev --dart-define-from-file=config/dev.json \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Usuario con onboarding terminado. Para los escenarios de foto, una clave de Gemini real (propia,
de desarrollo).

## 5. Escenarios

| # | Pasos | Resultado esperado | Requisito |
|---|---|---|---|
| 1 | Onboarding → paso de la clave → Omitir | Continúa sin clave; la foto aparece desactivada | US1.1, US4.1 |
| 2 | Ajustes → Clave de IA → pegar clave válida → Guardar | «Clave configurada» con la fecha | US1.2 |
| 3 | Ajustes → Clave de IA → pegar clave inválida → Guardar | Mensaje de error bajo el campo | US1.3 |
| 4 | Ajustes → Clave de IA → Quitar clave → Confirmar | Vuelve a «No configurada»; foto desactivada | US1.4 |
| 5 | Ajustes → ver la pantalla → inspeccionar | La clave no aparece en ningún sitio | US1.5 |
| 6 | Con clave → Desayuno → Foto → hacer foto → Analizar | Vuelve al diario con chip «Analizando…»; el usuario puede seguir registrando; al terminar aparece «Análisis listo» y toque abre la propuesta | US2.1, R8 |
| 7 | Propuesta: alimentos emparejados con kcal | Cada uno con nombre de la base y kcal calculadas | US2.2 |
| 8 | Cambiar gramos de un alimento → totales se recalculan | Los totales al pie cambian | US2.3 |
| 9 | Sustituir un alimento por otro de la base | La fila se actualiza con el nuevo alimento | US2.3 |
| 10 | Alimento sin pareja → Buscar → elegir uno | Se empareja; el botón Guardar se activa | US2.4 |
| 11 | Alimento sin pareja → Crear personalizado | Se crea y se empareja | US2.4 |
| 12 | Guardar la propuesta → ver el diario | Entradas en la comida elegida; resumen actualizado | US2.5 |
| 13 | Comprobar el servidor | 0 fotos guardadas; 0 respuestas con la clave | US2.6, SC-003 |
| 14 | Revocar la clave en Google → analizar | Borrador con «Tu clave no es válida» + ir a ajustes | US3.1 |
| 15 | Agotar la cuota → analizar | Borrador con «límite de tu cuenta del proveedor» | US3.2 |
| 16 | Foto que no es comida → analizar | Borrador con «continuar a mano» | US3.3 |
| 17 | Abrir un borrador → ver foto, comida y día → Reintentar | Se reabre el análisis | US3.4 |
| 18 | Borrador → Añadir a mano → registrar por búsqueda → el borrador desaparece | US3.5 |
| 19 | Borrador → Descartar → confirmar → desaparece de la lista | US3.5 |
| 20 | Sin clave → Desayuno → la opción de foto | Desactivada con texto + acceso a la guía | US4.1 |
| 21 | Sin clave → búsqueda, escáner, recientes, favoritos | Funcionan igual | US4.2 |
| 22 | Durante el análisis, registrar un alimento por búsqueda en la misma comida | Se añade normalmente; el chip «Analizando…» sigue visible | R8 |
| 23 | Análisis > 60 s (simular con timeout bajo) → borrador con «ha tardado demasiado» | Edge case |
| 24 | Sin conexión → Foto → no se envía → borrador con «Sin conexión» | Edge case |
| 25 | Gramos propuestos de 0 o 2500 → marcados con advertencia | Edge case |
| 26 | Permiso de cámara denegado → ofrecer galería | Edge case |
| 27 | Cerrar la app durante el análisis → abrir → el borrador aparece recuperable | Edge case, R8 |
| 28 | TalkBack en la guía, la propuesta y los borradores; texto al 200 % | FR-020 |
| 29 | Con el usuario B, `GET /v1/ai-key` y `POST /v1/photo-analysis` | No accede a datos de A | SC-003 |
| 30 | Fotografiar 20 platos habituales (lista propia, variada) con clave real y contar cuántos alimentos quedan emparejados sin que el usuario toque «Buscar»/«Crear» | ≥ 70 % emparejados automáticamente | SC-006 |

## 6. Cierre (principio IX)

La feature se fusiona en `dev` con las pruebas en verde y los escenarios superados contra el
backend local con la clave de Gemini real. Se da por cerrada cuando `dev` llega a `main`, Dokploy
despliega (la migración `0006_ai_key` se aplica al arrancar, `AI_KEY_MASTER` ya está en las
variables) y los escenarios 2, 6, 12, 14, 20 y 27 se repiten en el móvil contra producción (el 27,
no el 22, es el que cierra la app durante el análisis y comprueba el borrador recuperable).
