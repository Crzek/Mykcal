# Quickstart: validación de la 003

## 0. Antes de implementar: semilla de CIQUAL

1. Comprobar la licencia de la edición más reciente de CIQUAL en su ficha de
   recherche.data.gouv (research R1). Descargar los ficheros en una carpeta **fuera de git**, por
   ejemplo `~/datos/ciqual/`.
2. Revisar `backend/data/ciqual/ciqual_es.csv`, que tiene la selección, la traducción y los
   sinónimos (Erick).
3. Generar la semilla:

```bash
cd backend && uv run python scripts/build_generic_seed.py ~/datos/ciqual/ \
  data/ciqual/ciqual_es.csv src/mykcal/foods/data/generic_foods.csv
```

El script falla si un código curado no existe en CIQUAL o si le faltan kcal o macros (R3).

## 1. Pruebas automáticas

```bash
cd backend && uv run ruff check && uv run pytest
cd app && flutter analyze && flutter test
```

Todo en verde. En particular:

- `tests/integration/test_search_cases.py`: al menos 45 de los 50 casos de
  `contracts/search-cases.md` (SC-001).
- `tests/integration/test_barcode_lookup.py`: cada rama de research R9 con OFF simulado; el 100 %
  de `not_found` e `incomplete` devuelven el código para crear un personalizado (SC-003).
- `tests/privacy/test_user_isolation_foods.py`: el usuario B nunca ve un personalizado de A
  (SC-004).
- `tests/integration/test_generic_import.py`: dos cargas seguidas no duplican nada (FR-002).
- Ninguna prueba sale a Internet: el *fixture* de guarda de OFF falla si se crea un cliente real
  (FR-018).

## 2. Migración e importación en local

```bash
cd backend && docker compose -f docker-compose.dev.yml up -d
uv run alembic upgrade head                       # aplica 0003_foods sobre 0002_onboarding
uv run python -m mykcal.foods.load_generic        # generic_import_done, rows_upserted ≈ 600
uv run python -m mykcal.foods.load_generic        # generic_import_noop
```

`alembic downgrade -1` revierte `0003_foods`, incluida la extensión `pg_trgm` si la creó la
migración.

## 3. APK con backend local

No hay entorno `dev` desplegado (constitución 1.2.0). Antes de fusionar, los flujos se prueban
contra el backend local:

```bash
cd backend && uv run uvicorn mykcal.main:create_app --factory --host 0.0.0.0
cd app && flutter run --flavor dev --dart-define-from-file=config/dev.json \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulador; en el móvil, la IP del PC
```

Para Open Food Facts hace falta red real en esta prueba manual. Las automáticas nunca la usan.

## 4. Escenarios

| # | Pasos | Resultado esperado | Requisito |
|---|---|---|---|
| 1 | Inicio → Alimentos → escribir «platano» | «Plátano, crudo» entre los primeros, con kcal por 100 g | US1.1, FR-004 |
| 2 | Abrir «Plátano, crudo» | kcal, 3 macros, fibra y 7 micros por 100 g; los que faltan dicen «sin dato» | US1.2, FR-016 |
| 3 | Buscar «xyzzy» | «No hemos encontrado…» + «Crear alimento “xyzzy”» con el nombre puesto | US1.3 |
| 4 | Escribir «p» | No se busca; aviso de 2 letras | Edge case |
| 5 | Escanear un producto conocido (por ejemplo, un yogur) | Nombre, marca, valores por 100 g y ración si la hay | US2.1, FR-010 |
| 6 | Escanearlo otra vez, o con otro usuario | Sale en menos de 2 s; en los registros, `barcode_lookup result=cache` | US2.2, SC-002 |
| 7 | Escanear una bebida | Valores «Por 100 ml» | Edge case ml |
| 8 | Introducir a mano un código válido que OFF no conoce | Hoja «No conocemos este producto» → formulario con el código | US2.3, SC-003 |
| 9 | Introducir a mano un código con el dígito de control mal | «Revisa el código: no es válido», sin llamar al servidor | R9 |
| 10 | Denegar el permiso de cámara | Explicación + «Introducir el código a mano» | US2.5 |
| 11 | Crear «Tarta de la abuela» por 100 g con los 4 valores obligatorios | Se guarda en menos de 1 min; sale en la búsqueda como «Mío», antes que los genéricos | US3.1, US3.3, SC-005 |
| 12 | Crear un alimento por ración (150 g, 480 kcal) | Muestra «= 320 kcal por 100 g» y el detalle guarda por 100 g | US3.2, FR-013 |
| 13 | Poner proteína 50, carbohidratos 40 y grasa 20 | Error en los campos; no se guarda | FR-014 |
| 14 | Poner kcal 100 con P 10, C 10, G 10 (calculadas: 170) | Aviso de kcal; se puede guardar | FR-014 |
| 15 | Con otro usuario, buscar «tarta de la abuela» | No aparece | US3.4, SC-004 |
| 16 | Crear un personalizado con el código del escenario 5 y escanearlo | Sale el personalizado, no el de OFF | US3.6, FR-007 |
| 17 | Editar y después eliminar el personalizado | La búsqueda refleja la edición; tras eliminarlo, ya no aparece | US3.5 |
| 18 | Apagar la red y buscar | «Sin conexión» con «Reintentar»; se conserva lo escrito | Restricción técnica |
| 19 | Ajustes → Fuentes de datos | Atribución de CIQUAL y de Open Food Facts | R16 |
| 20 | TalkBack y texto al 200 % en las pantallas 1–5 | Todo se lee y nada se corta | FR-017 |

## 5. Cierre (principio IX)

La feature se fusiona en `dev` con las pruebas en verde y los escenarios superados contra el
backend local. Se da por cerrada cuando `dev` llega a `main`, Dokploy despliega (migración e
importación al arrancar) y los escenarios 1, 5, 8 y 11 se repiten en el móvil contra producción.
