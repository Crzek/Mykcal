# Casos de referencia del cálculo (SC-002)

Las pruebas unitarias de `mykcal/targets/calc.py` usan esta tabla como datos (`pytest.mark.parametrize`).
Cubre los dos sexos, los tres objetivos, los cinco niveles de actividad, los dos mínimos de kcal, el
corte de edad del hierro (50/51 años) y los carbohidratos negativos.

Reglas: `research.md` R2–R3 y `data-model.md`, «CalcInputs → CalcResult». Gasto y valores
redondeados con `ROUND_HALF_UP`. Las dos primeras filas son los ejemplos de la spec (US2.2 y US2.3).

| Sexo | Edad | Altura (cm) | Peso (kg) | Actividad | Objetivo | Gasto | kcal | Prot. (g) | Grasa (g) | Carb. (g) | Hierro (mg) | Avisos |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| H | 30 | 180 | 80 | moderate | maintain | 2759 | 2759 | 144 | 77 | 373 | 8 | — |
| H | 30 | 180 | 80 | moderate | lose_fat | 2759 | 2207 | 176 | 61 | 238 | 8 | — |
| H | 30 | 180 | 80 | moderate | gain_muscle | 2759 | 3035 | 160 | 84 | 409 | 8 | — |
| M | 35 | 165 | 60 | sedentary | maintain | 1554 | 1554 | 108 | 43 | 183 | 18 | — |
| H | 25 | 175 | 70 | light | gain_muscle | 2301 | 2532 | 140 | 70 | 335 | 8 | — |
| M | 40 | 170 | 65 | high | lose_fat | 2331 | 1865 | 143 | 52 | 207 | 18 | — |
| H | 28 | 190 | 95 | very_high | maintain | 3805 | 3805 | 171 | 106 | 542 | 8 | — |
| M | 30 | 165 | 60 | very_high | gain_muscle | 2508 | 2759 | 120 | 77 | 397 | 18 | — |
| M | 55 | 160 | 50 | sedentary | lose_fat | 1277 | 1200 | 110 | 33 | 115 | 8 | MIN_KCAL_APPLIED |
| H | 70 | 160 | 50 | sedentary | lose_fat | 1386 | 1500 | 110 | 42 | 171 | 8 | MIN_KCAL_APPLIED |
| M | 50 | 165 | 60 | light | maintain | 1678 | 1678 | 108 | 47 | 207 | 18 | — |
| M | 51 | 165 | 60 | light | maintain | 1671 | 1671 | 108 | 46 | 205 | 8 | — |
| M | 100 | 100 | 300 | sedentary | lose_fat | 3557 | 2845 | 660 | 79 | 0 | 8 | CARBS_CLAMPED |

H = hombre (`male`), M = mujer (`female`).

## Fibra y micros por sexo (FR-011)

| Sexo | Fibra (g) | Sodio (mg) | Potasio (mg) | Calcio (mg) | Magnesio (mg) | Vit. D (µg) | Vit. C (mg) |
|---|---|---|---|---|---|---|---|
| H | 30 | 2000 | 3500 | 1000 | 400 | 15 | 90 |
| M | 25 | 2000 | 3500 | 1000 | 310 | 15 | 75 |

El hierro está en la tabla principal porque depende de la edad en las mujeres.

## Propiedades

Además de los casos, una prueba recorre una rejilla de entradas (edades 18/50/51/100, alturas
100/250, pesos 30/300, los dos sexos y todos los niveles y objetivos) sin librerías nuevas
(research R17) y verifica:

- el mismo `CalcInputs` da siempre el mismo `CalcResult` (FR-012);
- `kcal ≥ mínimo(sexo)`;
- `carbs_g ≥ 0`;
- ningún valor de salida es negativo.
