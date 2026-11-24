# Flujos de interfaz

Completa `specs/002-onboarding-y-objetivo/contracts/ui-flows.md`. Todos los textos van en
`app_es.arb`. Todos los controles tienen etiqueta para el lector de pantalla, miden al menos
48 dp y respetan el tamaño de texto del sistema. Los números usan el formato español de
`core/format/numbers.dart` (FR-017, principio VIII).

Hasta que exista el diario (004), estas pantallas se abren desde **Inicio → «Alimentos»**. La
004 reutilizará la búsqueda, el escáner y el detalle añadiendo un botón «Añadir al diario».

## 1. Buscar alimentos

```
┌──────────────────────────────────────────┐
│ ← Alimentos                    [▦ Escanear]│  ← IconButton, etiqueta «Escanear código de barras»
│ [🔍 Busca un alimento           ] [✕]     │  ← TextField con autofocus
│                                          │
│ Mis alimentos                            │  ← solo si hay personalizados en el resultado
│  Tarta de la abuela   · Mío   320 kcal   │  ← distintivo «Mío» (US3.3)
│ Alimentos                                │
│  Plátano, crudo               90 kcal    │  ← «por 100 g» en el texto semántico
│  Plátano macho, frito        ...         │
│ Productos envasados                      │
│  Plátanos de Canarias · Marca  95 kcal   │
│                                          │
│ [ Mis alimentos ]                        │  ← abre la pantalla 5
└──────────────────────────────────────────┘
```

| Situación | Comportamiento |
|---|---|
| Menos de 2 caracteres | No se busca. Debajo del campo: «Escribe al menos 2 letras» |
| Escribiendo | La búsqueda se lanza 300 ms después de la última tecla; la respuesta de una consulta antigua se descarta |
| Cargando | `LinearProgressIndicator` bajo el campo y anuncio «Buscando…» |
| Sin resultados | «No hemos encontrado “{q}”.» + `[ Crear alimento “{q}” ]` → pantalla 4 con el nombre puesto (US1.3) |
| Sin conexión | «Sin conexión. Inténtalo de nuevo.» + `[ Reintentar ]`; se conserva lo escrito |
| Toca un resultado | Pantalla 2 |

Etiqueta semántica de cada fila: «{nombre}, {marca}, {kcal} kilocalorías por 100 gramos[, tuyo]».

## 2. Detalle de un alimento

```
┌──────────────────────────────────────────┐
│ ← Plátano, crudo                    [✎]  │  ← ✎ solo si is_mine
│ Genérico · CIQUAL                        │  ← o «Envasado · Open Food Facts» / «Tuyo»
│ Marca: …   Código: 8410…                 │  ← si existen
│ Ración del envase: 125 g                 │  ← si serving_size (FR-010)
│                                          │
│ Por 100 g                                │  ← «Por 100 ml» si base_unit = ml
│ Energía            90 kcal               │
│ Proteína            1,1 g                │
│ Carbohidratos      19,7 g                │
│ Grasa               0,3 g                │
│ Fibra               2,0 g                │
│ ── Micronutrientes ──                    │
│ Sodio               1 mg                 │
│ Potasio           358 mg                 │
│ Calcio              5 mg                 │
│ Hierro              0,3 mg               │
│ Magnesio           27 mg                 │
│ Vitamina D          sin dato             │  ← texto «sin dato», no «0» ni «—» (FR-016)
│ Vitamina C          8,7 mg               │
│                                          │
│ ⓘ Datos de una copia de más de 30 días   │  ← solo si stale
└──────────────────────────────────────────┘
```

- Una tabla con `Semantics` por fila: «Vitamina D: sin dato».
- Si algún micro o la fibra no tienen dato, al pie aparece: «Los nutrientes sin dato cuentan como
  0 en los totales.»

## 3. Escanear código de barras

```
┌──────────────────────────────────────────┐
│ ← Escanear                       [🔦]    │  ← linterna, si el móvil la tiene
│ ┌──────────────────────────────────────┐ │
│ │        vista de la cámara            │ │
│ │        [ marco de escaneo ]          │ │
│ └──────────────────────────────────────┘ │
│ Apunta al código de barras del envase    │
│ [ Introducir el código a mano ]          │
└──────────────────────────────────────────┘
```

| Situación | Comportamiento |
|---|---|
| Código leído | Vibración corta, la cámara se detiene, spinner «Buscando producto…» y `GET /v1/foods/barcode` |
| `found` | Pantalla 2 del alimento. Si es propio, lleva el distintivo «Tuyo» (US3.6) |
| `not_found` | Hoja: «No conocemos este producto.» + `[ Crear alimento con este código ]` → pantalla 4 con el código (US2.3) |
| `incomplete` | Hoja: «{nombre} no tiene información nutricional suficiente.» + `[ Crear alimento con este código ]` → pantalla 4 con nombre, marca y código (US2.4) |
| `503 FOOD_SOURCE_UNAVAILABLE` | Hoja: «No hemos podido consultar la base de productos.» + `[ Reintentar ]` `[ Crear alimento ]` |
| Sin conexión | «Sin conexión. Inténtalo de nuevo.» + `[ Reintentar ]` |
| Permiso denegado | Sin cámara: «Mykcal usa la cámara solo para leer códigos de barras. No guarda fotos.» + `[ Permitir cámara ]` `[ Introducir el código a mano ]` (US2.5) |
| Permiso denegado para siempre | Igual que arriba, pero en lugar de `[ Permitir cámara ]` el texto dice: «Puedes activarlo en Ajustes del sistema → Aplicaciones → Mykcal → Permisos.» |

**Introducir el código a mano** (diálogo): campo numérico con etiqueta «Código de barras (8 a 14
cifras)». Con un dígito de control incorrecto, error junto al campo: «Revisa el código: no es
válido». `[ Buscar ]` hace la misma consulta que el escáner.

## 4. Crear o editar un alimento personalizado

```
┌──────────────────────────────────────────┐
│ ← Nuevo alimento                [Guardar]│
│ Nombre*        [ Tarta de la abuela   ]  │
│ Marca          [                      ]  │
│ Código         [ 8410000000000        ]  │  ← precargado desde el escáner
│ Unidad         (•) Gramos  ( ) Mililitros│
│ Valores        (•) Por 100 g ( ) Por ración │
│ Ración         [ 150 ] g                 │  ← obligatoria si «Por ración»; opcional si no
│                                          │
│ Energía*       [ 320 ] kcal              │
│ Proteína*      [ 6   ] g                 │
│ Carbohidratos* [ 45  ] g                 │
│ Grasa*         [ 13  ] g                 │
│ ▸ Fibra y micronutrientes (opcional)     │  ← ExpansionTile con los 8 opcionales
│                                          │
│ ⚠ Las kcal no cuadran con los macros     │  ← aviso, no bloquea (FR-014)
│   (calculadas: 321 kcal)                 │
│ [ Guardar ]                              │
└──────────────────────────────────────────┘
```

**Validación** (en la app con `custom_food_check.dart` y otra vez en el servidor):

| Regla | Mensaje junto al campo |
|---|---|
| Obligatorio vacío | «Obligatorio» |
| Negativo | «No puede ser negativo» |
| Por encima del máximo por 100 | «Como máximo {max} {unidad} por 100 {g/ml}» |
| P + C + G + fibra > 100 por 100 | En los cuatro campos: «Proteína, carbohidratos, grasa y fibra suman más de 100 g por 100 g» |
| «Por ración» sin ración | En Ración: «Indica cuántos gramos tiene la ración» |
| Código no válido | «Revisa el código: no es válido» |
| `409 FOOD_BARCODE_TAKEN` | En Código: «Ya tienes un alimento con este código» |

- El aviso `KCAL_MISMATCH` aparece en directo mientras se escribe. Tiene icono y texto y el lector
  de pantalla lo anuncia (`liveRegion`). No impide guardar.
- Con «Por ración», debajo de cada valor se muestra su equivalente por 100 («= 213 kcal por
  100 g»), para que el usuario vea la conversión (FR-013).
- Al guardar, se vuelve a la pantalla 2 del alimento guardado.
- Sin conexión: `SnackBar` «Sin conexión. Inténtalo de nuevo.» y el formulario conserva todo.
- Al salir con cambios sin guardar, se pregunta: «¿Descartar los cambios?».
- SC-005: con el formulario por defecto (por 100 g y solo los 5 campos obligatorios) se crea en
  menos de 1 minuto.

## 5. Mis alimentos

Lista de los personalizados ordenada por nombre (`GET /v1/foods/custom`).

| Acción | Resultado |
|---|---|
| Tocar | Pantalla 2 |
| Mantener pulsado o menú `⋮` → «Editar» | Pantalla 4 en modo edición |
| Menú `⋮` → «Eliminar» | Diálogo: «¿Eliminar “{nombre}”? Las comidas ya registradas no cambian.» `[ Cancelar ]` `[ Eliminar ]` |
| Lista vacía | «Aún no has creado alimentos.» + `[ Crear alimento ]` |
| `[+]` (FAB, etiqueta «Crear alimento») | Pantalla 4 vacía |

## 6. Fuentes de datos (Ajustes)

Nueva entrada en Ajustes: **«Fuentes de datos»**. Muestra los dos textos de atribución de R16 y
la dirección web de cada fuente como texto seleccionable. No se añade `url_launcher` solo para
esto (principio VII).

## Cambios en pantallas existentes

| Pantalla | Cambio |
|---|---|
| Inicio | Botón «Alimentos» → pantalla 1 |
| Ajustes | Entrada «Fuentes de datos» → pantalla 6 |
