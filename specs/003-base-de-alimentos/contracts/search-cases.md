# Casos de búsqueda (SC-001)

La spec pide que el plan fije la lista de 50 alimentos frescos habituales. Criterio de aceptación:
al menos **45 de 50** (90 %) tienen un resultado **aceptable** entre los **5 primeros** al buscar
la consulta escrita aquí.

La prueba es `backend/tests/integration/test_search_cases.py`. Lee esta tabla, carga la semilla
real (`generic_foods.csv`) y busca con un usuario sin alimentos personalizados. Un resultado es
aceptable si su nombre normalizado **empieza por** alguno de los prefijos aceptados (separados
por `|`).

Las consultas se escriben como las escribiría alguien con prisa: sin tildes, en minúsculas y
en singular. Cuando un caso falla, se arregla con un sinónimo o un nombre mejor en
`backend/data/ciqual/ciqual_es.csv` (research R6), no con código.

| # | Consulta | Prefijos aceptados |
|---|---|---|
| 1 | platano | platano |
| 2 | manzana | manzana |
| 3 | naranja | naranja |
| 4 | pera | pera |
| 5 | fresa | fresa |
| 6 | uva | uva |
| 7 | sandia | sandia |
| 8 | melon | melon |
| 9 | kiwi | kiwi |
| 10 | melocoton | melocoton |
| 11 | pina | pina |
| 12 | aguacate | aguacate |
| 13 | tomate | tomate |
| 14 | lechuga | lechuga |
| 15 | zanahoria | zanahoria |
| 16 | cebolla | cebolla |
| 17 | patata cocida | patata |
| 18 | pimiento | pimiento |
| 19 | calabacin | calabacin |
| 20 | brocoli | brocoli |
| 21 | espinaca | espinaca |
| 22 | pepino | pepino |
| 23 | judia verde | judia verde|judias verdes |
| 24 | champinon | champinon |
| 25 | arroz cocido | arroz |
| 26 | arroz integral | arroz integral |
| 27 | pasta cocida | pasta|macarron|espagueti |
| 28 | pan blanco | pan |
| 29 | pan integral | pan integral |
| 30 | avena | avena|copos de avena |
| 31 | lenteja | lenteja |
| 32 | garbanzo | garbanzo |
| 33 | alubia | alubia|judia blanca |
| 34 | pechuga de pollo | pechuga de pollo|pollo, pechuga |
| 35 | ternera | ternera |
| 36 | cerdo lomo | lomo de cerdo|cerdo, lomo |
| 37 | jamon serrano | jamon serrano|jamon curado |
| 38 | pavo | pavo |
| 39 | huevo | huevo |
| 40 | salmon | salmon |
| 41 | merluza | merluza |
| 42 | atun en lata | atun |
| 43 | sardina | sardina |
| 44 | gamba | gamba|langostino |
| 45 | leche entera | leche entera|leche de vaca entera |
| 46 | leche desnatada | leche desnatada|leche de vaca desnatada |
| 47 | yogur natural | yogur natural|yogur |
| 48 | queso fresco | queso fresco |
| 49 | aceite de oliva | aceite de oliva |
| 50 | nuez | nuez|nueces |

Además, la prueba comprueba los ejemplos de la spec:

- «platano» devuelve un nombre que empieza por «Plátano» en el primer puesto (US1.1, con tilde
  en el nombre y sin tilde en la consulta).
- «PLÁTANO» y «Platano» devuelven lo mismo que «platano» (FR-004).
- «p» → `400 VALIDATION_ERROR` (edge case «Búsqueda muy corta»).
- Una consulta sin coincidencias (por ejemplo, «xyzzy») → `items: []` (US1.3).
