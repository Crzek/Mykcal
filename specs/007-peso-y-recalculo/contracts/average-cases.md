# Casos de referencia de la media semanal y el umbral (SC-002, FR-009)

Las pruebas unitarias de `mykcal/weight/average.py` usan estas tablas como datos
(`pytest.mark.parametrize`). Reglas: `research.md` R3. Media redondeada a **1 decimal con
ROUND_HALF_UP**; umbral **estrictamente > 2%** sobre el peso de referencia (`calc_weight_kg`).

## Media semanal `weekly_average(entries, as_of)`

Registros dados como `(días_antes_de_as_of, peso_kg)`. Ventana = `[as_of−6, as_of]`.

| Caso | Registros en ventana | Media esperada | Nota |
|---|---|---|---|
| Suficientes | (0, 78.0) (1, 78.5) (2, 79.0) | 78.5 | media exacta |
| Redondeo HALF_UP | (0, 78.1) (1, 78.2) (2, 78.2) | 78.2 | 78.166… → 78.2 |
| Redondeo .x5 | (0, 78.0) (1, 78.1) (2, 78.2) (3, 78.3) | 78.2 | 78.15 → 78.2 (medio hacia arriba) |
| Justo 3 registros | (0, 76.0) (3, 76.0) (6, 76.0) | 76.0 | mínimo válido |
| Menos de 3 | (0, 77.0) (1, 77.0) | None | no se calcula para recálculo |
| Hueco fuera de ventana | (0, 78.0) (1, 78.0) (2, 78.0) (8, 70.0) | 78.0 | el de 8 días no entra |
| Solo hoy | (0, 76.0) | None | oscilación diaria, no cuenta (US3.3) |

## Umbral `exceeds_threshold(average, reference)`

Referencia (peso del último cálculo) = 80.0 kg salvo que se indique. Umbral = 2% de 80 = 1.6 kg.

| Caso | Media | Referencia | Esperado | Nota |
|---|---|---|---|---|
| Por debajo (US3.1) | 78.2 | 80.0 | True | −2.25% |
| Cerca pero por debajo (US3.2) | 78.6 | 80.0 | False | −1.75% |
| Justo en 2.0% | 78.4 | 80.0 | False | exactamente 2% no dispara (estrictamente mayor) |
| Un paso por encima | 78.3 | 80.0 | True | −2.125% |
| Subida simétrica | 81.7 | 80.0 | True | +2.125% |
| Subida justo 2% | 81.6 | 80.0 | False | exactamente 2% |
| Variación grande >10% | 71.0 | 80.0 | True | además `large_change` (R7) |

## Serie de la gráfica `moving_average_series(entries, days)`

- Cada día **con** registro aporta un punto de peso; los días sin registro no se dibujan (sin
  interpolación).
- La media móvil de un día existe solo si su ventana de 7 días tiene **≥3 registros**; si no, `None`.

| Caso | Entrada | Media de ese día |
|---|---|---|
| Ventana con 3 | día D y 2 registros en los 6 días previos | valor redondeado |
| Ventana con 2 | día D y 1 registro previo | None (punto de peso sí, de media no) |
| Primer registro | solo D | peso sí, media None |
| Ventana que cruza el inicio del periodo | D es el primer día de `p30` y 2 registros de su ventana son anteriores al periodo | media con 3 registros (la ventana no se recorta por el periodo) |
