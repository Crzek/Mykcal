# Quickstart: validar «Peso y recálculo del objetivo»

Guía de validación de extremo a extremo. Los detalles de reglas y esquemas están en
[data-model.md](./data-model.md), [contracts/api-changes.md](./contracts/api-changes.md) y
[contracts/average-cases.md](./contracts/average-cases.md).

## Prerrequisitos

- Backend local con PostgreSQL (Docker Compose) y migraciones aplicadas hasta `0006`.
- Usuario con cuenta activa, consentimiento aceptado y objetivo creado (onboarding de 002).
- App Flutter apuntando al backend local, o `curl` con un `bearerToken` válido.

## Puesta en marcha

```bash
# Backend
cd backend
alembic upgrade head          # incluye 0006_weight_recalc (tabla recalc_proposal)
uvicorn mykcal.main:create_app --factory --reload

# App
cd app
flutter run
```

## Pruebas automáticas (deben pasar antes de fusionar — principio IX)

```bash
cd backend
pytest tests/unit/test_weight_average.py      # media, redondeo y umbral (SC-002, FR-009)
pytest tests/integration/test_weight_entries.py
pytest tests/integration/test_recalc_proposal.py
pytest tests/contract/test_weight_contract.py
pytest tests/privacy                          # aislamiento por usuario incluye peso (FR-010)

cd ../app
flutter test
```

## Escenarios de validación manual

### V1 — Registrar, editar y borrar peso (US1)

1. En «Peso», introduce `78.4` para hoy → se guarda y aparece en la lista.
2. Introduce otro peso para hoy → sustituye al anterior (un registro por día).
3. Elige una fecha pasada e introduce un peso → se guarda en esa fecha.
4. Intenta `25` o `310` → se rechaza con el rango 30–300.
5. Intenta una fecha futura → el selector no lo permite; una petición directa devuelve
   `400 VALIDATION_ERROR`.
6. Edita y borra un registro → la gráfica se actualiza.

### V2 — Gráfica (US2)

1. Con registros de varias semanas, abre la gráfica → ves puntos diarios y la línea de media semanal
   de los últimos 30 días.
2. Cambia a 90 días y a «todo» → el periodo se ajusta.
3. Con lector de pantalla → hay resumen textual (peso actual, media semanal, variación) y lista.
4. Con menos de 2 registros → mensaje de «necesitas más registros».

### V3 — Propuesta de recálculo (US3)

Partiendo de un objetivo calculado con 80 kg:

1. Carga ≥3 registros en los últimos 7 días con media **78.2** (−2.25%) y abre la app →
   `GET /v1/recalc-proposal` devuelve `pending` y se muestra el diálogo con objetivo actual y nuevo.
2. Con media **78.6** (−1.75%) → no hay propuesta (`status: none`).
3. Con un único registro de 76 kg en 7 días → no hay propuesta (menos de 3).
4. **Acepta** → el objetivo se recalcula con las reglas de 002 usando 78.2 como peso; ese peso pasa a
   ser `calc_weight_kg`. Verifica con `GET /v1/target`.
5. **Ignora** otra propuesta → no reaparece durante 7 días (comprueba que `GET /v1/recalc-proposal`
   devuelve `none` aunque siga superándose el umbral).
6. Con el objetivo editado a mano y umbral superado → la propuesta avisa de que aceptar sustituye los
   valores editados (`was_manual: true`).
7. Cierra el diálogo sin responder y reabre la app → la misma propuesta vuelve a mostrarse.

### V4 — Comprobación en el móvil (principio IX)

Tras desplegar, repite V1–V3 en el APK: registrar el peso en <10 s desde la pantalla principal
(SC-001) y confirmar que la propuesta aparece solo cuando corresponde (SC-002, SC-003).
