# Research: 003 — Base de alimentos, código de barras y alimentos personalizados

Decisiones técnicas de la feature. Las reglas de producto están cerradas en la spec. Aquí se
decide **cómo** se implementan.

---

## R1. Base genérica: CIQUAL con nombres traducidos al español (pregunta abierta 6)

**Decisión**: la base genérica es la tabla **CIQUAL** de ANSES (Francia). Se importa una
selección curada de alimentos (unos 600) con los nombres traducidos al español. Erick lo
decidió el 2026-11-24 y con ello se cierra la pregunta abierta 6.

- Edición: la más reciente publicada (CIQUAL 2025, en recherche.data.gouv). Antes de construir
  la semilla hay que comprobar en la ficha del conjunto de datos que su licencia sigue siendo la
  *Licence Ouverte / Etalab 2.0*. Si no lo es, se usa CIQUAL 2020 de data.gouv.fr, que sí la
  tiene. Esto no cambia el diseño, solo los valores.
- Atribución obligatoria: «Anses. Table de composition nutritionnelle des aliments Ciqual»,
  con la edición. Aparece en la pantalla *Fuentes de datos* de la app y en
  `backend/src/mykcal/foods/data/FUENTES.md`.

**Rationale**:
- Las [condiciones de uso de BEDCA](https://www.bedca.net/bdpub/UsoBD.pdf) piden autorización
  expresa para cualquier uso electrónico que no sea personal, educativo o no comercial, prohíben
  modificar los datos y no ofrecen descarga masiva oficial.
- CIQUAL tiene licencia abierta que permite reutilizar y transformar los datos citando la
  fuente, se descarga entera y cubre todos los nutrientes de FR-001: kcal (Reglamento UE
  1169/2011), proteína, carbohidratos, grasa, fibra, sodio, potasio, calcio, hierro, magnesio,
  vitamina D y vitamina C.
- Es una tabla europea con alimentos parecidos a los españoles.

**Alternativas**:
- BEDCA con autorización: bloquearía la feature hasta tener la respuesta de AESAN.
- BEDCA asumida como uso no comercial: riesgo legal que se puede evitar.
- USDA FoodData Central: es de dominio público, pero sus alimentos y nombres son estadounidenses.

## R2. Semilla generada y versionada en el repositorio

**Decisión**: hay dos ficheros en el repositorio y un script que genera uno a partir del otro:

1. `backend/data/ciqual/ciqual_es.csv` (curado a mano): `ciqual_code;name_es;synonyms`. Aquí
   está la selección y la traducción. `synonyms` lleva variantes separadas por `|`: nombres
   regionales, palabras sin la preparación y formas en plural (por ejemplo, «banana|plátano de
   Canarias»).
2. `backend/scripts/build_generic_seed.py`: lee los ficheros oficiales de CIQUAL, descargados
   a mano en una carpeta local que no entra en git, y el CSV curado. Escribe
   `backend/src/mykcal/foods/data/generic_foods.csv` con el nombre en español, los sinónimos y
   los 12 nutrientes por 100 g. La cabecera lleva la edición de CIQUAL.
3. La semilla generada **sí** se versiona y entra en la imagen Docker.

**Rationale**: la importación en el servidor no descarga nada y siempre da el mismo resultado
(principio VI). Las pruebas usan la misma semilla que producción. La traducción queda revisable
en un diff.

**Alternativas**: importar el XML completo de CIQUAL (unos 3.000 alimentos) y traducirlo todo.
Se rechaza: duplica el trabajo de traducción y añade ruido a la búsqueda («baba au rhum» y
platos franceses que no se buscarán nunca).

## R3. Lectura de los valores de CIQUAL

**Decisión**: el script de la semilla convierte cada celda así:

| Valor en CIQUAL | Resultado |
|---|---|
| número con coma decimal (`12,5`) | `12.5` |
| `-` o vacío | `null` (sin dato, FR-003) |
| `traces` | `0` |
| `< x` (por debajo del límite) | `0` |

- Las kcal salen de la columna «Énergie, Règlement UE N° 1169/2011 (kcal/100 g)».
- Los carbohidratos salen de «Glucides (g/100 g)».
- Un alimento sin kcal, proteína, carbohidratos o grasa no entra en la semilla: el script falla
  y nombra el código, para que se quite del CSV curado.

**Rationale**: «trazas» y «< límite» son cantidades despreciables, no datos que faltan. Contarlos
como «sin dato» marcaría como incompletos casi todos los totales del diario (FR-016).

## R4. Importación idempotente al arrancar

**Decisión**: el módulo `mykcal.foods.load_generic` hace un *upsert* por `(source, source_code)`.
`docker-entrypoint.sh` lo lanza después de las migraciones. Funciona así:

- Calcula el SHA-256 de la semilla y lo compara con el último guardado en `food_import`. Si
  coincide, no hace nada (`generic_import_noop`).
- Si cambia, inserta o actualiza todos los alimentos en una transacción y guarda el hash nuevo.
- Los alimentos genéricos que ya no están en la semilla se archivan (`archived_at`), no se
  borran: las entradas del diario de la 004 pueden apuntar a ellos. Un alimento archivado no sale
  en la búsqueda.
- Usa el mismo bloqueo consultivo que `mykcal.migrate`, para que dos contenedores no importen a
  la vez.
- En local también se puede lanzar con `uv run python -m mykcal.foods.load_generic`.

**Rationale**: cumple FR-002 (repetir la carga no duplica alimentos) sin ningún paso manual al
desplegar. Con unos 600 alimentos la carga tarda menos de un segundo.

**Alternativas**: cargar los datos en una migración de Alembic. Se rechaza: actualizar valores
obligaría a escribir otra migración y mezcla el esquema con los datos.

## R5. Una sola tabla `food` para los tres tipos

**Decisión**: tabla `food` con `kind` en `generic | packaged | custom`. `owner_user_id` existe
solo en los personalizados, y lo garantiza una restricción. Los nutrientes son columnas
`NUMERIC` que admiten `NULL`, y `NULL` significa «sin dato» (FR-003). Detalle en
`data-model.md`.

**Rationale**: la búsqueda (FR-005), el detalle y la 004, que apuntará a un único `food_id`,
trabajan con una sola tabla. Las diferencias entre tipos son pocas: dueño, fecha de consulta y
origen.

**Alternativas**: una tabla por tipo con una vista `UNION`. Complica las claves ajenas de la 004
y el orden de la búsqueda.

## R6. Búsqueda: texto normalizado en Python + `pg_trgm`

**Decisión**:
- Columna `search_text`: nombre, marca y sinónimos en minúsculas y sin tildes, normalizados en
  Python con `unicodedata` (NFKD y quitar las marcas diacríticas). La consulta se normaliza con
  la misma función `normalize()`. Así no hace falta la extensión `unaccent`, que además no es
  `IMMUTABLE` y complica los índices.
- Extensión `pg_trgm` (de confianza desde PostgreSQL 13, la crea el dueño de la base) e índice
  GIN `gin_trgm_ops` sobre `search_text`.
- Filtro: `search_text LIKE '%' || q || '%'` o `q <% search_text` (similitud de palabra
  ≥ 0,5). Solo alimentos visibles para el usuario: genéricos y envasados no archivados y
  personalizados propios no eliminados.
- Orden (FR-005 y edge case «Muchos resultados»):
  1. tipo: personalizados del usuario, después genéricos y después envasados;
  2. coincidencia exacta del nombre, después nombre que empieza por la consulta, después una
     palabra que empieza por la consulta y después el resto;
  3. `word_similarity` descendente;
  4. nombre más corto primero («Plátano, crudo» antes que «Plátano macho, frito»).
- Límite 20. Con menos de 2 caracteres normalizados, `400 VALIDATION_ERROR` (la app no llega a
  lanzar la búsqueda).

**Rationale**: con unos 600 genéricos más los envasados consultados, PostgreSQL basta y no hace
falta un motor de búsqueda (principio VII). La lista de 50 alimentos de SC-001
(`contracts/search-cases.md`) es una prueba de integración contra la semilla real. Si un caso
falla, se corrige con un sinónimo en `ciqual_es.csv`, no con código.

**Alternativas**: `tsvector` con diccionario español. El *stemming* falla con nombres de
alimentos y no tolera errores de escritura. Meilisearch o similar: infraestructura nueva sin
necesidad medida.

## R7. Cliente de Open Food Facts

**Decisión**: módulo `mykcal/foods/off_client.py` con `httpx.AsyncClient`, que ya es
dependencia:

- `GET https://world.openfoodfacts.org/api/v2/product/{code}` con `fields=` limitado a lo que se
  usa: `code,product_name,product_name_es,brands,nutriments,serving_quantity,
  serving_quantity_unit,product_quantity_unit`.
- `User-Agent` desde la variable `OFF_USER_AGENT`, como pide Open Food Facts. Valor por defecto:
  `Mykcal/0.3 (app privada)`. Erick puede añadir un contacto en Dokploy si quiere; el código no
  lleva ningún dato personal.
- Tiempo máximo de 5 s y sin reintentos automáticos: la app ofrece «Reintentar».
- El transporte se puede inyectar (`create_app(off_transport=…)`), igual que `oidc_transport`.
  En las pruebas siempre es un `httpx.MockTransport` con *fixtures* (FR-018, principio VI).

Resultados:

| Respuesta de OFF | Resultado |
|---|---|
| `status: 1` con kcal, proteína, carbohidratos y grasa | `found`: se guarda la copia y se devuelve |
| `status: 1` sin alguno de esos cuatro valores | `incomplete`: no se guarda; se devuelven nombre y marca (US2.4) |
| `status: 0` o HTTP 404 | `not_found` (US2.3) |
| tiempo agotado, error de red o 5xx | `503 FOOD_SOURCE_UNAVAILABLE` (edge case «Base pública caída») |

**Rationale**: con 50 usuarios, una consulta por escaneo nuevo está muy por debajo de los límites
de OFF. Pedir solo los campos necesarios reduce la respuesta a unos pocos KB.

## R8. Conversión de los nutrientes de OFF

**Decisión**: los campos `*_100g` de OFF vienen en gramos, así que se convierten:

| OFF | Mykcal | Factor |
|---|---|---|
| `energy-kcal_100g` (o `energy-kj_100g` / 4,184 si falta) | `kcal` | 1 |
| `proteins_100g`, `carbohydrates_100g`, `fat_100g`, `fiber_100g` | `*_g` | 1 |
| `sodium_100g`, `potassium_100g`, `calcium_100g`, `iron_100g`, `magnesium_100g`, `vitamin-c_100g` | `*_mg` | × 1.000 |
| `vitamin-d_100g` | `vitamin_d_ug` | × 1.000.000 |

- Un campo que no existe se guarda como `null` (sin dato). Se redondea a 2 decimales con
  `ROUND_HALF_UP`.
- Unidad base: `ml` si `product_quantity_unit` es `ml` (o `cl`/`l`); `g` en el resto de casos.
  En OFF, los valores `_100g` de un líquido ya son por 100 ml (edge case «Producto con datos
  en ml»).
- Ración: `serving_quantity` (> 0) en la unidad base. Si no existe, no hay ración (FR-010).
- Nombre: `product_name_es` si existe; si no, `product_name`; si tampoco, «Producto sin
  nombre».

**Rationale**: una sola tabla de conversión, pura y cubierta por pruebas con *fixtures* reales
guardadas.

## R9. Código de barras: validación y orden de búsqueda

**Decisión**:
- Se aceptan GTIN de 8, 12, 13 o 14 dígitos con dígito de control válido. Los UPC-A de 12
  dígitos se guardan con un 0 delante (EAN-13), así un mismo producto tiene siempre la misma
  clave. Un código no válido devuelve `400 VALIDATION_ERROR` con `fields: ["code"]`, y la app
  avisa en la introducción manual antes de llamar.
- Orden de búsqueda (FR-007):
  1. alimento personalizado propio, no eliminado, con ese código (US3.6);
  2. copia local (`kind = packaged`) consultada hace 30 días o menos (US2.2, FR-008);
  3. Open Food Facts. Si responde `found`, se hace un *upsert* de la copia con `fetched_at = now`.
- Copia caducada (más de 30 días): se vuelve a consultar OFF. Si OFF falla, se devuelve la copia
  antigua con `stale: true`: es mejor que no mostrar nada. Si OFF ya no tiene el producto, se
  conserva la copia y también se devuelve con `stale: true`.
- Los códigos no encontrados no se guardan (YAGNI): con 50 usuarios, repetir la consulta no
  cuesta nada.
- El código va como parámetro de consulta (`GET /v1/foods/barcode?code=…`) y no en la ruta, para
  que el registro de accesos, que guarda la ruta, no lo incluya (R15).

**Rationale**: la copia caducada evita el error en el caso más habitual de OFF lento. La
normalización a EAN-13 evita duplicados.

## R10. Alimentos personalizados: entrada, conversión y validación

**Decisión**:
- La petición lleva `basis: "per_100" | "per_serving"`. Con `per_serving` también lleva
  `serving_size` (> 0, en la unidad base) y el servidor convierte a 100 (FR-013):
  `valor_100 = valor_ración × 100 / ración`, redondeado a 2 decimales con `ROUND_HALF_UP`.
  Se guardan los valores por 100 y la ración.
- Obligatorios: nombre (1–120 caracteres, recortado), kcal, proteína, carbohidratos y grasa.
  Opcionales: fibra, micros, marca (≤ 80), código de barras y ración. La unidad base es `g` por
  defecto; `ml` es opcional.
- Errores bloqueantes (`400 VALIDATION_ERROR` con los nombres de los campos, FR-014):
  - valor negativo;
  - proteína + carbohidratos + grasa + fibra > 100 por 100 g o ml, tras convertir. La fibra
    cuenta porque en CIQUAL y en OFF no forma parte de los carbohidratos;
  - un valor por encima de su máximo por 100 (kcal ≤ 900; sodio ≤ 40.000 mg, etc.,
    `data-model.md`).
- Aviso, sin bloquear: `KCAL_MISMATCH` si `|kcal − (4·P + 4·C + 9·G)| / (4·P + 4·C + 9·G) > 0,15`.
  Si el cálculo da 0 y kcal > 0, también hay aviso. Se devuelve en `warnings` al guardar. La
  app lo muestra antes de guardar con `custom_food_check.dart`, que replica la regla, igual que
  `macro_check.dart` en la 002.
- Código de barras: como mucho un personalizado activo por usuario y código (índice único
  parcial). Si se repite, `409 FOOD_BARCODE_TAKEN`.

**Rationale**: contar la fibra evita aceptar valores imposibles (por ejemplo, 60 g de
carbohidratos y 60 g de fibra). Validar en los dos
lados da respuesta inmediata en la app, y el servidor tiene la última palabra.

## R11. Editar y eliminar sin tocar el pasado (FR-015)

**Decisión**:
- Editar cambia la fila en su sitio (`updated_at`).
- Eliminar es un borrado lógico (`deleted_at`): el alimento deja de salir en la búsqueda, en el
  código de barras y en «Mis alimentos», pero la fila sigue existiendo.
- **Compromiso para la 004**: cada entrada del diario copia los valores nutricionales del
  alimento en el momento de registrarla. Así, editarlo o eliminarlo nunca cambia lo ya
  registrado. Esta feature no tiene diario; la regla queda escrita aquí y en `data-model.md` para
  que la 004 la cumpla.

**Alternativas**: versionar los alimentos (como `daily_target`). Es innecesario si el diario
guarda su propia copia de los valores.

## R12. Sumas con datos incompletos (FR-016)

**Decisión**: función pura `mykcal/foods/nutrients.py::sum_nutrients(items) -> Totals`. Cada
elemento lleva unos valores por 100 y una cantidad. La función escala, suma con `Decimal`, cuenta
cada `null` como 0 y devuelve `incomplete: set[nutriente]` con los nutrientes que tenían algún
`null`. En esta feature solo la usan las pruebas unitarias; la 004 la usará para los totales del
día. En la app, «sin dato» se muestra con `nutrient_format.dart`.

**Rationale**: la regla de FR-016 queda fijada y probada ahora, en el mismo sitio que la
definición de los nutrientes, aunque la pantalla de totales llegue con la 004.

## R13. Escáner: `mobile_scanner` con ML Kit incluido

**Decisión**: paquete `mobile_scanner` ^7 (CameraX + ML Kit en Android, minSdk 23, compatible
con nuestra API 24):

- Modelo de ML Kit **incluido** en el APK (unos 3–10 MB más). La alternativa «sin incluir» pesa
  unos 600 KB pero descarga el modelo la primera vez desde Google Play Services, y el primer
  escaneo podría fallar sin red o en móviles sin servicios de Google.
- Formatos limitados a `ean13`, `ean8`, `upcA` y `upcE`. Se detiene la cámara al primer código
  válido para no repetir la consulta.
- Permiso de cámara (US2.5): si se deniega, la pantalla explica para qué se usa la cámara y
  ofrece «Introducir el código a mano». Si se deniega de forma permanente, el texto indica cómo
  activarlo en los ajustes del sistema. No se añade un paquete solo para abrir los ajustes
  (principio VII).
- `AndroidManifest.xml`: `android.permission.CAMERA` y
  `<uses-feature android:name="android.hardware.camera" android:required="false"/>`, para que
  la app se instale también en dispositivos sin cámara.

**Alternativas**: `flutter_zxing` o `google_mlkit_barcode_scanning` con `camera`. Supondrían
más código propio para el mismo resultado.

## R14. Rutas y consentimiento

**Decisión**: todas las rutas `/v1/foods/**` exigen cuenta activa **y consentimiento**
(`require_consent`). Se añaden a `HEALTH_DATA_ROUTES` de `tests/privacy/test_consent_gate.py`.
Un alimento personalizado de otro usuario responde `404 FOOD_NOT_FOUND`, nunca `403`, para no
revelar que existe (principio V, SC-004).

**Rationale**: los alimentos personalizados y lo que busca o escanea una persona describen su
alimentación. La app solo llega a estas pantallas después del onboarding, así que el requisito
no añade ningún paso.

## R15. Registros sin contenido sensible (principio X)

**Decisión**:
- Eventos: `food_search` (número de resultados y duración, **sin la consulta**),
  `barcode_lookup` (`result`: `custom|cache|off_found|off_not_found|off_incomplete|off_error|stale`
  y duración, **sin el código**), `custom_food_saved` y `custom_food_deleted` (solo con el `id`),
  `generic_import_done` y `generic_import_noop` (con el hash y el número de filas).
- La consulta y el código van en el *query string*, que el registro de accesos no guarda
  (`request.url.path`).
- `tests/privacy/test_logs_no_secrets.py` añade un caso: buscar «chorizo» y escanear un código
  conocido no dejan ninguno de los dos textos en los registros.

## R16. Atribución y licencias

**Decisión**: pantalla *Fuentes de datos* en Ajustes, con texto en ARB:

- «Alimentos genéricos: Anses, Table de composition nutritionnelle des aliments Ciqual
  (edición). Licence Ouverte 2.0. Nombres traducidos y selección por Mykcal.»
- «Productos envasados: Open Food Facts, disponible bajo la Open Database License (ODbL).»

La copia local de OFF es una base derivada de uso interno que no se distribuye. La obligación
de compartir igual de la ODbL se aplicaría si se publicara esa base, y no es el caso.

## R17. Dependencias nuevas

| Dónde | Dependencia | Motivo |
|---|---|---|
| PostgreSQL | extensión `pg_trgm` (contrib, incluida en la imagen oficial) | Búsqueda tolerante (R6) |
| App | `mobile_scanner` ^7 | Escáner (R13) |

En el backend no se añade nada (`httpx` ya está). Ninguna pieza de infraestructura nueva.

## R18. Pruebas

- **Unitarias (backend)**:
  - `normalize()`;
  - conversión de OFF con *fixtures* reales guardadas en `tests/fixtures/off/`: en gramos, en
    ml con ración, solo kJ, sin macros, `status: 0`;
  - validación GTIN y paso de UPC-A a EAN-13;
  - conversión por ración y validación de personalizados (incluido `KCAL_MISMATCH` en el límite
    del 15 %);
  - `sum_nutrients` con valores `null`;
  - lectura de las celdas de CIQUAL (R3).
- **Integración (testcontainers)**:
  - importación idempotente: dos cargas dan el mismo número de filas; con la semilla cambiada se
    archivan los genéricos que ya no están;
  - búsqueda (SC-001 con `contracts/search-cases.md` y la semilla real);
  - orden de tipos en los resultados;
  - código de barras en cada rama de R9 con OFF simulado: caché, caducado, OFF caído con copia
    antigua y sin ella;
  - CRUD de personalizados.
- **Privacidad**:
  - SC-004: el usuario B no ve en la búsqueda, el código, el detalle, la lista, la edición ni el
    borrado el alimento personalizado de A;
  - consentimiento en las rutas nuevas;
  - registros sin la consulta ni el código.
- **Red**: un *fixture* de sesión hace fallar la prueba si alguien crea un cliente de OFF sin
  transporte simulado (FR-018).
- **App**:
  - widgets y accesibilidad (semántica, tamaño de texto 200 %, contraste) de las pantallas
    nuevas;
  - prueba pura de `custom_food_check.dart` con los mismos casos que el backend;
  - escáner con `MobileScannerController` simulado: permiso denegado y código leído.
