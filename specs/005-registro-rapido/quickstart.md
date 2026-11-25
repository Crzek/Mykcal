# Quickstart: validación de la 005

## 1. Pruebas automáticas

```bash
cd backend && uv run ruff check && uv run pytest
cd app && flutter analyze && flutter test
```

Todo en verde. En particular:

- `tests/unit/test_quick_suggest.py`, `test_quick_ordering.py` y `test_copy_rules.py`: todos los
  casos de `contracts/quick-cases.md`.
- `tests/integration/test_recent_foods.py`: un alimento registrado 3 veces sale una vez con su
  último uso; 35 alimentos distintos → 30; una entrada borrada no cuenta; un personalizado borrado
  y un genérico archivado no salen (FR-001, casos límite).
- `tests/integration/test_favorites.py`: `PUT` dos veces deja un favorito; `DELETE` de uno que no
  lo es da `204`; orden de FR-010; un personalizado borrado desaparece de la lista.
- `tests/integration/test_diary_copy.py`:
  - Copiar a una comida con entradas las suma sin borrar nada (US3.3).
  - La comida origen queda idéntica, fila a fila (SC-003).
  - Origen fuera de los 14 días o igual al destino → `400 DIARY_DATE_OUT_OF_RANGE`; origen vacío →
    `400 COPY_SOURCE_EMPTY`.
  - Valores actuales o conservados según V1–V5.
  - Deshacer borra solo las copiadas; a los 61 s o por segunda vez → `404 COPY_NOT_FOUND`.
- `tests/integration/test_diary_entries.py`: `POST` devuelve `Location` con el id de la entrada.
- `tests/privacy/test_user_isolation_quick.py` (SC-004):
  - B no ve recientes ni favoritos de A.
  - B no puede marcar un personalizado de A (`404`).
  - `copy-sources` de B nunca incluye comidas de A.
  - B no puede deshacer una copia de A (`404`).
- `tests/contract/test_quick_contract.py`: respuestas válidas contra `openapi.yaml` 0.5.0, y
  `GET /v1/foods/recent` no responde 422 (orden de routers, research R10).

## 2. Migración en local

```bash
cd backend && docker compose -f docker-compose.dev.yml up -d
uv run alembic upgrade head        # aplica 0005_quick sobre 0004_diary
uv run alembic downgrade -1        # elimina favorite_food y diary_entry.copy_id
uv run alembic upgrade head
```

## 3. APK con backend local

```bash
cd backend && uv run uvicorn mykcal.main:create_app --factory --host 0.0.0.0
cd app && flutter run --flavor dev --dart-define-from-file=config/dev.json \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulador; en el móvil, la IP del PC
```

Usuario con onboarding terminado y, para los escenarios de copia, algunas entradas en días
anteriores.

## 4. Escenarios

| # | Pasos | Resultado esperado | Requisito |
|---|---|---|---|
| 1 | Usuario sin entradas → Desayuno → + | Pestaña Recientes con el mensaje de vacío | US1.4 |
| 2 | Registrar pan (60 g), leche (250 ml) y pan otra vez (90 g) → Cena → + | Recientes: Pan de molde 90 g arriba, Leche 250 ml; el pan sale una vez | US1.1, casos límite |
| 3 | En Recientes, «+» del pan | Entrada de 90 g en Cena con un toque; aviso de 5 s; la pantalla sigue abierta; menos de 5 s desde Inicio | US1.2, SC-001 |
| 4 | Repetir 3 y tocar «Deshacer» antes de 5 s | La entrada desaparece y el resumen vuelve | FR-007 |
| 5 | Repetir 3 y esperar | El aviso se va a los 5 s; la entrada sigue | FR-007 |
| 6 | En Recientes, tocar el nombre del pan | Hoja de cantidad con 90 g; cambiar a 120 g → añadir | US1.3 |
| 7 | Marcar ☆ en un resultado de búsqueda, en un reciente y en la hoja de una entrada | Los tres salen en Favoritos | US2.1, FR-003 |
| 8 | Favorito con ración nunca usado → «+» | Se añade 1 ración; uno sin ración, 100 g | US2.2, FR-004 |
| 9 | Ver el orden de Favoritos | Usados por último uso; nunca usados al final por nombre | FR-010 |
| 10 | Desmarcar en Favoritos | Desaparece; «Deshacer» lo devuelve | US2.3 |
| 11 | Borrar en «Mis alimentos» un personalizado que es reciente y favorito | Deja de salir en las dos pestañas; sus entradas siguen | Caso límite |
| 12 | Desayuno de hoy → ⋮ → Copiar de otro día | Días anteriores (hasta 14), desayunos primero en cada día, sin comidas vacías | US3.1, FR-005 |
| 13 | Elegir el desayuno de ayer → Copiar | Todas sus entradas en el desayuno de hoy; resumen actualizado; ayer sin cambios; menos de 15 s | US3.2, SC-002, SC-003 |
| 14 | Copiar a una comida con entradas | Se suman a las que había | US3.3 |
| 15 | Copiar la comida de ayer a la cena de hoy | Permitido | US3.4 |
| 16 | Copiar y «Deshacer» antes de 5 s | Se quitan solo las copiadas | US3.5 |
| 17 | Editar un personalizado (más kcal) y copiar una comida antigua que lo tiene | Aviso «Algún alimento ha cambiado»; la copia sale con los valores nuevos | FR-006 |
| 18 | Borrar ese personalizado y copiar otra vez | La copia conserva los valores de la entrada original | FR-006 |
| 19 | Con el usuario B, abrir Recientes, Favoritos y Copiar | No aparece nada de A | FR-008, SC-004 |
| 20 | Modo avión → «+» en un reciente, y → Copiar | Aviso «Sin conexión» con «Reintentar»; la hoja de copiar conserva la selección | Restricción técnica |
| 21 | TalkBack en Recientes y en la hoja de copiar; texto al 200 % | «Añadir Pan de molde, 90 g»; cada comida se lee entera; nada se corta | FR-009 |

## 5. Cierre (principio IX)

La feature se fusiona en `dev` con las pruebas en verde y los escenarios superados contra el
backend local. Se da por cerrada cuando `dev` llega a `main`, Dokploy despliega (la migración
`0005_quick` se aplica al arrancar) y los escenarios 3, 8, 13 y 16 se repiten en el móvil contra
producción.
