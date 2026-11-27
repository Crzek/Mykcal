# Quickstart: validar la selección dinámica de modelo

Guía de validación. Contratos en [contracts/provider-and-errors.md](contracts/provider-and-errors.md)
y datos en [data-model.md](data-model.md).

## Requisitos

- Backend con dependencias instaladas (`backend/`).
- Ninguna clave real: las pruebas usan `FakeProvider` y `httpx.MockTransport`.

## 1. Pruebas automáticas

```bash
cd backend
pytest tests/unit/test_ai_model_selector.py tests/test_ai_gemini_validate.py \
       tests/integration/test_photo_analysis.py tests/privacy -q
```

Resultado esperado: todo en verde. Cubren, por historia:

| Historia | Escenario simulado | Resultado esperado |
|----------|--------------------|--------------------|
| US1 | La preferencia ya no figura en el listado | Análisis correcto con otro modelo; el registro dice `selection=fallback` |
| US1 | Sin preferencia | Se elige el mejor `flash-lite`/`flash` |
| US2 | 1.º en 503, 2.º correcto | Resultado del 2.º; 2 intentos registrados |
| US2 | 1.º en 429, 2.º correcto | Resultado del 2.º |
| US2 | Todos en 503 / todos en 429 | `AI_PROVIDER_UNAVAILABLE` / `AI_QUOTA_EXCEEDED` |
| US2 | Segunda petición justo tras un 503 | No vuelve a llamar al modelo saturado durante 3 min |
| US3 | Preferencia con dos modelos disponibles | Usa el primero; si desaparece, el segundo |
| US4 | Todos los modelos en 503 | `PUT /v1/ai-key` con clave válida → 200 |
| US5 | Fallos de cada tipo | Cada uno deja su `category` en el registro |
| Caché | Dos análisis seguidos | Un solo `GET` de listado |
| Caché | Reloj +24 h | Vuelve a pedir el listado |
| Aislamiento | Dos claves distintas | Dos listados; no se mezclan |
| Sin modelo | Listado sin modelos compatibles | `AI_NO_MODEL_AVAILABLE` (503) |
| Privacidad | Cualquier fallo | El registro no contiene clave, foto ni cuerpo |

## 2. Comprobación en el móvil (tras desplegar desde `main`)

1. Despliega sin `AI_MODEL` (o vacío). Haz una foto de un plato con una clave válida: debe proponer
   alimentos.
2. Mira el registro: `ai_analysis` con `model=…` y `selection=fallback`.
3. Pon `AI_MODEL=nombre-que-no-existe` y repite: el análisis sigue funcionando y aparece
   `ai_model_preference_ignored`.
4. Guarda una clave nueva: se acepta aunque el modelo esté saturado.

## 3. Comprobación de que no se filtran datos

```bash
cd backend && pytest tests/privacy -q
```
