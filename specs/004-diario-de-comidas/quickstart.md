# Quickstart: validación de la 004

## 1. Pruebas automáticas

```bash
cd backend && uv run ruff check && uv run pytest
cd app && flutter analyze && flutter test
```

Todo en verde. En particular:

- `tests/unit/test_diary_summary.py` y `tests/unit/test_day_end.py`: todos los casos de
  `contracts/summary-cases.md` (SC-002, FR-011).
- `tests/integration/test_diary_entries.py`: crear, editar, mover, borrar y restaurar; restaurar a
  los 61 s da `404`.
- `tests/integration/test_diary_snapshot.py`: editar y borrar el personalizado no cambia la entrada
  ni sus valores al editar la cantidad (SC-004).
- `tests/privacy/test_user_isolation_diary.py`: el usuario B recibe `404` en las rutas de entrada
  con un `id` de A, y su día nunca incluye entradas de A (SC-005).
- `tests/contract/test_diary_contract.py`: respuestas válidas contra `openapi.yaml` 0.4.0.

## 2. Migración en local

```bash
cd backend && docker compose -f docker-compose.dev.yml up -d
uv run alembic upgrade head        # aplica 0004_diary sobre 0003_foods
uv run alembic downgrade -1        # elimina diary_entry
uv run alembic upgrade head
```

## 3. APK con backend local

```bash
cd backend && uv run uvicorn mykcal.main:create_app --factory --host 0.0.0.0
cd app && flutter run --flavor dev --dart-define-from-file=config/dev.json \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulador; en el móvil, la IP del PC
```

Usuario con onboarding terminado (objetivo de 2.000 kcal, por ejemplo).

## 4. Escenarios

| # | Pasos | Resultado esperado | Requisito |
|---|---|---|---|
| 1 | Abrir la app sin entradas hoy | Inicio = diario de hoy: consumido 0, restante = objetivo, 5 comidas vacías en orden | US1.1, FR-001, FR-012 |
| 2 | Desayuno → + → «pan» → 150 g de un alimento de 200 kcal/100 g → Añadir | Entrada de 300 kcal; resumen y total de Desayuno al momento; en menos de 30 s desde «+» | US2.1, SC-001, SC-003 |
| 3 | Escanear un envasado con ración de 30 g → 2 raciones | Entrada «2 raciones · 60 g» con sus valores | US2.2 |
| 4 | En la hoja, cambiar la cantidad | La vista previa cambia mientras se escribe | US2.3 |
| 5 | Cantidad vacía, 0 o −5 | Mensaje y botón desactivado | US2.4 |
| 6 | Cantidad 6.000 g | Diálogo de confirmación | Caso límite |
| 7 | Añadir otra vez el mismo pan al Desayuno | Dos entradas separadas | Clarificación 1 |
| 8 | Editar la entrada del escenario 3 | Se abre en «2 raciones»; cambiar a 3 recalcula; pasar a 45 g guarda en g | US3.1, US3.2 |
| 9 | Mover una entrada de Comida a Cena | Cambian los totales de las dos comidas; el del día no | US3.3 |
| 10 | Borrar una entrada → «Deshacer» antes de 10 s | Vuelve con los mismos valores | US3.4, FR-005 |
| 11 | Borrar una entrada y esperar 10 s | El aviso desaparece y la entrada sigue borrada al recargar | Clarificación 3 |
| 12 | Superar las kcal del objetivo | «+N kcal» con icono y texto, no solo color | US1.3, FR-014 |
| 13 | Ver detalle con un alimento sin fibra registrado | Fibra con «incompleto» y su explicación | US1.4, FR-008 |
| 14 | Registrar un personalizado y después editarlo y borrarlo en «Mis alimentos» | La entrada conserva nombre y valores | Caso límite, SC-004 |
| 15 | ‹ (ayer) → añadir y borrar entradas → › | Ayer cambia y hoy no | US4.1, US4.2 |
| 16 | Editar el objetivo hoy y volver a ayer | Ayer usa el objetivo antiguo; hoy, el nuevo | US4.3, FR-011 |
| 17 | Intentar ir a mañana o antes del alta | «›» desactivado en hoy; «‹» desactivado en el día del alta; el calendario no los ofrece | US4.4, FR-010 |
| 18 | Dejar la app en «hoy» pasada la medianoche y volver | Muestra el día nuevo | Caso límite |
| 19 | Modo avión → añadir | La hoja sigue abierta con la cantidad; aviso «Sin conexión» con «Reintentar» | Caso límite |
| 20 | Menú ⋮ → Alimentos | Búsqueda y «Mis alimentos» de la 003 siguen disponibles | ui-flows |
| 21 | TalkBack y texto al 200 % en el diario y la hoja | Cada fila del resumen se lee completa; nada se corta | FR-014 |

## 5. Cierre (principio IX)

La feature se fusiona en `dev` con las pruebas en verde y los escenarios superados contra el
backend local. Se da por cerrada cuando `dev` llega a `main`, Dokploy despliega (la migración
`0004_diary` se aplica al arrancar) y los escenarios 1, 2, 10 y 16 se repiten en el móvil contra
producción.
