# Casos del resumen diario (SC-002, FR-006–FR-011)

Casos fijos para `tests/unit/test_diary_summary.py` y `tests/unit/test_day_end.py`. En todos,
`consumido + restante = objetivo` para cada nutriente. Objetivo base salvo que se diga otro:
2.000 kcal, 150 g proteína, 200 g carbohidratos, 56 g grasa, 25 g fibra, 2.300 mg sodio.

## Cálculo de entradas y totales

| # | Entradas (por 100 → cantidad) | Consumido | Restante | Notas |
|---|---|---|---|---|
| S1 | ninguna | 0 kcal, 0 / 0 / 0 g | 2.000 kcal, 150 / 200 / 56 g | 5 comidas vacías |
| S2 | 200 kcal → 150 g | 300 kcal | 1.700 kcal | US2.1 |
| S3 | 389 kcal, 13,2 g prot → 30 g × 2 raciones | 60 g: 233 kcal, 7,9 g prot | 1.767 kcal | `quantity = 60,0`, `servings = 2` (US2.2) |
| S4 | 3 entradas de 33,3 kcal → 100 g cada una | 100 kcal | 1.900 kcal | Se redondea el total (99,9 → 100), no cada entrada |
| S5 | entradas que suman 2.150 kcal | 2.150 kcal | −150 kcal | Exceso: la app muestra «+150 kcal» (US1.3) |
| S6 | A con fibra 3 g/100 → 100 g; B sin fibra → 100 g | fibra 3,0 g | 22,0 g | `fiber_g` en `incomplete` (FR-008) |
| S7 | sal 1.000 mg sodio/100 → 250 g | 2.500 mg sodio | −200 mg | Sodio es un máximo: «200 mg por encima del límite» |
| S8 | 12,25 g prot/100 → 100 g; 0,05 g/100 → 100 g | 12,3 g | 137,7 g | `ROUND_HALF_UP` a 1 decimal: 12,30 → 12,3 |
| S9 | mismo alimento 2 veces en Desayuno (100 g y 50 g de 200 kcal/100) | 300 kcal | 1.700 kcal | 2 entradas; Desayuno total 300 (clarificación 1) |
| S10 | entrada borrada (`deleted_at` no nulo) de 500 kcal | 0 kcal | 2.000 kcal | No se suma ni se devuelve |

## Totales por comida

| # | Situación | Resultado |
|---|---|---|
| M1 | 100 kcal en Comida, 200 kcal en Cena | Comida 100, Cena 200, día 300; las otras 3 en 0 |
| M2 | Mover la entrada de Comida a Cena (M1) | Comida 0, Cena 300, día 300 (US3.3) |
| M3 | Orden en la respuesta | `breakfast, lunch, afternoon_snack, dinner, snacks` siempre, aunque estén vacías |

## Objetivo vigente en un día (FR-011, research R3)

Versiones de un usuario: V1 `effective_from = 2026-11-10T08:00Z` (2.000 kcal), V2
`2026-11-15T22:30Z` (1.800 kcal).

| # | Día | `utc_offset_min` | Fin del día (UTC) | Objetivo |
|---|---|---|---|---|
| T1 | 2026-11-12 | 60 | 2026-11-12T23:00Z | V1 |
| T2 | 2026-11-15 | 60 | 2026-11-15T23:00Z | V2 (creada a las 23:30 locales: rige el día que cambió) |
| T3 | 2026-11-15 | −300 | 2026-11-16T05:00Z | V2 |
| T4 | 2026-11-15 | 120 | 2026-11-15T22:00Z | V1 (a las 22:00Z aún no existía V2) |
| T5 | 2026-11-09 (antes de V1) | 60 | 2026-11-09T23:00Z | V1 (la más antigua) |
| T6 | hoy | cualquiera | futuro | La vigente |

## Raciones y cantidades (research R6)

| # | Petición | Resultado |
|---|---|---|
| Q1 | `servings: 1.5`, `serving_size: 33,3` | `quantity = 50,0` (49,95 → 50,0) |
| Q2 | `servings: 2` en alimento sin ración | `400 VALIDATION_ERROR`, `fields: ["servings"]` |
| Q3 | `quantity` y `servings` a la vez | `400 VALIDATION_ERROR` |
| Q4 | `quantity: 0`, `-5` o ausente sin `servings` | `400 VALIDATION_ERROR` (US2.4) |
| Q5 | `quantity: 10000.1` | `400 VALIDATION_ERROR` |
| Q6 | `PATCH` con `quantity: 80` sobre entrada en raciones | `quantity = 80`, `servings = null` |
| Q7 | `PATCH` con `servings: 3` tras cambiar el alimento su ración a 40 g | `quantity = 90` (usa la ración copiada, 30 g) |
