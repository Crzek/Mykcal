# Casos de prueba de las reglas puras

Casos fijos para las pruebas unitarias del backend. Cada tabla corresponde a una función pura sin
base de datos.

## Cantidad sugerida — `quick/suggest.py` (research R2, FR-004)

| # | Última entrada | Alimento hoy | `suggested_quantity` | `suggested_servings` |
|---|---|---|---|---|
| A1 | 150 g, sin raciones | sin ración | 150 | null |
| A2 | 2 raciones de 30 g (60 g) | ración 30 g | 60 | 2 |
| A3 | 2 raciones de 30 g (60 g) | ración 40 g (personalizado editado) | 60 | null |
| A4 | 2 raciones de 30 g (60 g) | sin ración (editado) | 60 | null |
| A5 | 45 g, sin raciones | ración 30 g | 45 | null |
| A6 | ninguna (favorito sin uso) | ración 30 g | 30 | 1 |
| A7 | ninguna (favorito sin uso) | sin ración, unidad g | 100 | null |
| A8 | ninguna (favorito sin uso) | sin ración, unidad ml | 100 | null |
| A9 | 0,5 raciones de 250 ml (125 ml) | ración 250 ml | 125 | 0.5 |

## Orden de favoritos — `quick/ordering.py` (FR-010)

Entrada: favoritos con su último uso. Salida esperada en orden.

| # | Favoritos (nombre, último uso) | Orden esperado |
|---|---|---|
| O1 | Yogur (ayer 9:00), Avena (hoy 8:00), Plátano (hace 3 días) | Avena, Yogur, Plátano |
| O2 | Zumo (nunca), Ñoquis (nunca), Aceite (nunca), Leche (hoy) | Leche, Aceite, Ñoquis, Zumo |
| O3 | «Álamo» (nunca), «alubias» (nunca), «Arroz» (nunca) | Álamo, alubias, Arroz (sin tildes ni mayúsculas: alamo < alubias < arroz) |
| O4 | Dos con el mismo último uso: «Pan» y «Huevo» | Huevo, Pan (desempate por nombre) |

`normalize` de la 003 ordena «ñ» como «n»: O2 lo fija. Es aceptable para listas cortas.

## Orden de comidas para copiar — `diary/copy_rules.py` (R7, FR-005)

Destino: `target_meal = dinner`. Orden fijo de la 004: breakfast, lunch, afternoon_snack, dinner,
snacks.

| # | Comidas con entradas ese día | Orden esperado |
|---|---|---|
| C1 | breakfast, lunch, dinner | dinner, breakfast, lunch |
| C2 | breakfast, snacks | breakfast, snacks |
| C3 | dinner | dinner |
| C4 | (ninguna) | el día no aparece |

Días: para `target_date = 2026-11-24` la ventana es 2026-11-10 … 2026-11-23, del 23 al 10. El
2026-11-24 y el 2026-11-09 no aparecen nunca.

## Valores de la copia — `diary/copy_rules.py` (R6, FR-006)

Entrada origen: «Mi bizcocho», personalizado, 300 kcal/100 g, ración 50 g, 2 raciones (100 g).

| # | Estado del alimento al copiar | kcal/100 de la copia | `quantity` | `servings` | Nombre |
|---|---|---|---|---|---|
| V1 | Sin cambios | 300 | 100 | 2 | Mi bizcocho |
| V2 | Editado: 350 kcal/100 g, nombre «Bizcocho casero», ración 50 g | 350 | 100 | 2 | Bizcocho casero |
| V3 | Editado: ración 80 g | 300 | 100 | null | Mi bizcocho |
| V4 | Borrado | 300 | 100 | 2 | Mi bizcocho |
| V5 | Genérico archivado por una reimportación de CIQUAL | los de la entrada | los de la entrada | los de la entrada | el de la entrada |

En todos, la entrada origen queda idéntica (SC-003).
