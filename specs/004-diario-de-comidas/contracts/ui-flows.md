# Pantallas y flujos de la app

Textos en `app_es.arb`. Números con formato español (`1.850 kcal`, `12,3 g`). Todas las pantallas
respetan el tamaño de texto del sistema y los temas claro y oscuro (principio VIII).

Comidas: `breakfast` = «Desayuno», `lunch` = «Comida», `afternoon_snack` = «Merienda»,
`dinner` = «Cena», `snacks` = «Picoteo».

## 1. Inicio = diario del día (US1, US4, FR-012)

```text
┌──────────────────────────────────────┐
│ Mykcal                            ⋮  │
│  ‹   Hoy, lunes 24 nov    📅    ›    │  ← cabecera de día
│ ┌──────────────────────────────────┐ │
│ │ Calorías  1.850 / 2.000          │ │
│ │ ███████████████░░  Quedan 150    │ │
│ │ Proteína  120 / 150 g  Quedan 30 │ │
│ │ Carbohid. 210 / 200 g  ⚠ +10 g   │ │  ← exceso: icono + texto + color
│ │ Grasa      50 / 56 g   Quedan 6  │ │
│ │ [Ver detalle]       [Ver objetivo]│ │
│ └──────────────────────────────────┘ │
│ Desayuno                 420 kcal  + │
│   Pan integral · 60 g      150 kcal  │
│   Leche · 250 ml           160 kcal  │
│ Comida                     0 kcal  + │
│   Aún no hay nada                    │
│ Merienda …  Cena …  Picoteo …        │
└──────────────────────────────────────┘
```

- **Cabecera de día**:
  - «‹» va al día anterior. Se desactiva en el día del alta (`Me.registered_at` en fecha local).
  - «›» va al siguiente. Se desactiva en hoy: no hay días futuros (US4.4).
  - 📅 abre `showDatePicker` con `firstDate` = alta y `lastDate` = hoy.
  - El título dice «Hoy», «Ayer» o la fecha completa («sábado 22 nov»).
  - En un día pasado aparece «Ir a hoy».
- **Redondeo**: las entradas se muestran redondeadas y el total se calcula con los valores sin
  redondear, así que puede diferir en 1 de la suma visible de las entradas.
- **Tarjeta de resumen** (FR-006):
  - Calorías y los 3 macros con consumido, objetivo y restante.
  - Exceso: «+150 kcal» con icono `warning_amber` y color de error. Lectura accesible: «Calorías:
    2.150 de 2.000, 150 por encima».
  - Si un macro está en `incomplete`, aparece «incompleto» con icono de información.
- **Ver detalle** (FR-007, US1.4): hoja con fibra y los 7 micros.
  - Formato: «Fibra 18,0 / 25 g».
  - Sodio: «Sodio 1.900 mg · máx. 2.300 · quedan 400», o «300 por encima del límite».
  - Los nutrientes en `incomplete` llevan «incompleto», con la explicación: «Algún alimento de hoy
    no tiene este dato; cuenta como 0».
- **Ver objetivo**: abre la pantalla del objetivo de la 002 (ver y editar). Si el día que se ve es
  pasado, avisa: «Este día usó el objetivo que tenías entonces».
- **Comidas** (FR-001, FR-009):
  - Siempre las 5, en orden, cada una con su total de kcal en la cabecera.
  - Cada entrada: nombre, marca si la hay, cantidad («60 g», «2 raciones · 60 g») y kcal.
  - Tocar una entrada la edita (pantalla 3). «+» añade (pantalla 2).
  - Comida vacía: «Aún no hay nada».
- **Estados**:
  - Cargando: indicador.
  - Sin conexión o error: `ConnectionErrorView` con «Reintentar».
  - Al volver a primer plano en «hoy» con la fecha local cambiada: se carga el día nuevo
    (medianoche).

## 2. Añadir un alimento (US2)

1. «+» en una comida abre `FoodSearchScreen` en **modo selección**. El título es «Añadir a
   Desayuno». Tocar un resultado devuelve el alimento en vez de abrir el detalle. El escáner y
   «Crear alimento» siguen disponibles: si se crea un personalizado, se devuelve ese.
2. Se abre la hoja **Cantidad**:

```text
┌──────────────────────────────────────┐
│ Pan integral                         │
│ Desayuno · lunes 24 nov              │
│ Cantidad [ 60    ]  (g) (raciones)   │  ← raciones solo si el alimento tiene ración
│ 1 ración = 30 g                      │
│ 150 kcal · P 5,4 · C 25,1 · G 1,9 g  │  ← vista previa en vivo
│                         [ Añadir ]   │
└──────────────────────────────────────┘
```

- Unidad por defecto: raciones (1) si el alimento tiene ración. Si no, g/ml, con el campo vacío y
  el foco en él.
- La vista previa se recalcula al escribir (US2.3) con `entry_math.dart`, la misma fórmula que el
  servidor.
- **Validación** (US2.4): vacío, 0 o negativo → «Indica una cantidad mayor que 0», con el botón
  desactivado. Más de 10.000 g/ml → «Máximo 10.000».
- **Más de 5.000 g/ml**: diálogo «¿Seguro? Son 6.000 g» con «Cambiar» y «Sí, añadir» (caso
  límite).
- **Añadir**: la hoja se cierra, la búsqueda también, y se vuelve al diario con el día de la
  respuesta. Aviso breve: «Añadido a Desayuno».
- **Sin conexión o error**: la hoja sigue abierta con lo escrito y muestra «Sin conexión. Revisa
  la red y vuelve a intentarlo» con «Reintentar».

## 3. Editar una entrada (US3, clarificaciones 2 y 3)

La misma hoja, con:

- La cantidad en la unidad con que se registró (raciones si `servings` no es nulo), y la opción de
  pasar a g/ml.
- Selector «Comida» con las 5, solo del mismo día (US3.3).
- «Guardar» envía `PATCH` y «Borrar» envía `DELETE`.
- La vista previa usa la copia de la entrada (`DiaryEntry.per_100` y `serving_size`), no el
  alimento actual (FR-004).

## 4. Borrar y deshacer (US3.4)

- Tras `DELETE`: el diario se actualiza con la respuesta y aparece un `SnackBar` de **10 s**:
  «Pan integral borrado» con «Deshacer».
- «Deshacer» envía `restore` y el diario vuelve a actualizarse. Si falla (`404` o red): «No se pudo
  deshacer».
- El `SnackBar` se anuncia al lector de pantalla y no se cierra solo mientras tiene el foco de
  accesibilidad.

## Cambios en pantallas existentes

| Pantalla | Cambio |
|---|---|
| `HomeScreen` | Pasa a ser el diario (pantalla 1). Sin saludo ni botón «Alimentos» |
| Menú ⋮ | Añade «Alimentos» (búsqueda en modo consulta de la 003) |
| `TargetCard` | Sale de Inicio. Se llega al objetivo desde «Ver objetivo» |
| `FoodSearchScreen` | Parámetro opcional `onSelected` para el modo selección |
| `BarcodeResultFlow` | En modo selección, «encontrado» devuelve el alimento |
