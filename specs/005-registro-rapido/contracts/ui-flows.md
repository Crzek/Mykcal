# Flujos de la app

Pantallas que cambian y estados de cada una. Todos los textos van al ARB (`app_es.arb`); aquí
aparecen como se leerán.

## 1. Añadir a una comida (cambia `food_search_screen.dart` en modo selección)

Se abre desde «+» de una comida del diario, como en la 004. Título: «Añadir a Desayuno».

```text
┌───────────────────────────────────────┐
│ ← Añadir a Desayuno               [▦] │  ▦ = escanear (003)
│ [🔍 Buscar alimento              ]    │
│ ┌ Recientes ┐  Favoritos              │  ← solo con el campo vacío
│ Pan de molde · Bimbo        ☆  [+]    │
│ 2 raciones · 60 g · 150 kcal          │
│ Leche semidesnatada         ★  [+]    │
│ 250 ml · 115 kcal                     │
│ …                                     │
│ [ Crear alimento ]                    │  (003)
└───────────────────────────────────────┘
```

- **Campo vacío**: pestañas Recientes y Favoritos. Abre en Recientes. Al escribir, las pestañas se
  ocultan y se ven los resultados de la 003; al borrar, vuelven en la pestaña en que estaban.
- **Fila** (`quick_food_tile.dart`), igual en las dos pestañas:
  - Línea 1: nombre y marca. Línea 2: cantidad sugerida y kcal (con `entry_math.dart` de la 004).
  - Tocar la fila abre la hoja de cantidad de la 004 con la cantidad sugerida ya puesta (US1.3).
  - Estrella: marca o desmarca (R9). Etiqueta: «Marcar Pan de molde como favorito» o «Quitar Pan
    de molde de favoritos». No empieza por «Añadir», para no confundirse con el «+» en TalkBack.
  - «+»: añade con la cantidad sugerida (US1.2, US2.2). Etiqueta: «Añadir Pan de molde, 2
    raciones, 60 g» (FR-009). Mientras se envía, el «+» pasa a indicador de progreso y no admite
    otro toque.
  - Área táctil de 48 × 48 dp como mínimo en «+» y en la estrella.
- **Después de añadir rápido**: la pantalla sigue abierta. Aviso de 5 s «Pan de molde añadido a
  Desayuno» con «Deshacer» (FR-007). El día del diario se actualiza con la respuesta.
  - Deshacer → `DELETE /v1/diary/entries/{id}` (id de la cabecera `Location`), aviso «Deshecho».
  - Si deshacer falla: «No se pudo deshacer. Borra la entrada desde el diario.»
- **Estados de Recientes**:
  - Cargando: indicador.
  - Vacío (US1.4): «Aquí aparecerán los alimentos que registres, para añadirlos con un toque.»
  - Error de red: «Sin conexión» con «Reintentar».
- **Estados de Favoritos**:
  - Vacío: «Marca alimentos con ☆ para tenerlos a mano aquí.»
  - Al desmarcar en esta pestaña, la fila desaparece (US2.3) con un aviso de 5 s «Quitado de
    favoritos» y «Deshacer» (vuelve a marcar). Es una mejora sobre FR-007 (research R4).
- **Búsqueda (003)**: cada resultado gana la estrella (FR-003). No gana «+»: el resultado no tiene
  cantidad previa.

## 2. Hoja de una entrada (cambia `entry_quantity_sheet.dart`)

En modo editar, la cabecera gana la estrella del alimento (FR-003). Si el alimento ya no está
disponible (`404 FOOD_NOT_FOUND` al marcar), aviso «Este alimento ya no está disponible» y la
estrella vuelve a su estado.

## 3. Copiar de otro día (nuevo `copy_meal_sheet.dart`)

Se abre desde el menú ⋮ de la cabecera de cada comida en el diario (`meal_section.dart`):
«Copiar de otro día». La comida y el día destino son los de esa sección.

```text
┌───────────────────────────────────────┐
│ Copiar a Cena · hoy                   │
│ Ayer, domingo 23                      │
│  ○ Cena            620 kcal           │
│     Merluza 150 g · Patata 200 g · …  │
│  ○ Desayuno        410 kcal           │
│     Pan de molde 60 g · Leche 250 ml  │
│ Sábado 22                             │
│  ○ Comida          780 kcal           │
│ …                                     │
│                [Cancelar] [Copiar]    │
└───────────────────────────────────────┘
```

- Lista de `GET /v1/diary/copy-sources`: días del más reciente al más antiguo, «Ayer» para el día
  anterior; dentro, primero la comida del mismo tipo (US3.1).
- Cada comida muestra sus entradas (hasta 3 y «+N más», que se despliega al tocar) y su total.
- Selección única (radio). «Copiar» se activa al elegir una.
- Si la comida tiene `values_changed`: línea «Algún alimento ha cambiado: se copiará con sus
  valores actuales.»
- Vacío: «No hay comidas en los 14 días anteriores.»
- **Copiar** → `POST /v1/diary/copies`. Se cierra la hoja, el día se actualiza con `day` y aparece
  un aviso de 5 s «3 alimentos copiados a Cena» con «Deshacer» (US3.5).
  - Deshacer → `DELETE /v1/diary/copies/{copy_id}`, día actualizado, aviso «Copia deshecha».
- Sin conexión: la hoja sigue abierta con la selección y aviso «Sin conexión» con «Reintentar».
- Accesibilidad: cada opción se lee entera: «Cena de ayer, 620 kcal, 3 alimentos: Merluza 150 g,
  Patata 200 g, Aceite de oliva 10 ml».

## 4. Avisos con deshacer (nuevo `undo_snack.dart`)

Una función común para los tres avisos de 5 s (añadido rápido, quitar favorito, copia), con
`persist: false` como el de la 004. El aviso de borrar de la 004 sigue con sus 10 s.

## Estado en la app

| Provider | Contenido |
|---|---|
| `recentFoodsProvider` | `AsyncNotifier` de `GET /v1/foods/recent`. `DiaryDayController.apply(day)` hace `ref.invalidate(recentFoodsProvider)`: así se invalida tras crear, editar, borrar, restaurar, copiar o deshacer. |
| `favoritesControllerProvider` | `AsyncNotifier` de `GET /v1/foods/favorites` con `toggle(food)` optimista. |
| `favoriteIdsProvider` | `Set<String>` derivado, para la estrella en cualquier pantalla. |
| `copySourcesProvider.family(fecha, comida)` | `FutureProvider.autoDispose` de la hoja de copiar. |
