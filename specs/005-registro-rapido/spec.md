# Feature Specification: Registro rápido (recientes, favoritos y copiar comidas)

**Feature Branch**: `005-registro-rapido`

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "005-registro-rapido: recientes, favoritos y copiar comidas. Épica E7."

## Clarifications

### Session 2026-11-24

- Q: ¿Recientes global o filtrado por la comida en que se abre "añadir"? → A: Global: los 30 últimos alimentos distintos del usuario, sin importar la comida.
- Q: ¿Cuántos segundos dura la opción de deshacer? → A: 5 segundos.
- Q: ¿Hasta cuántos días atrás se puede buscar una comida para copiar? → A: Los 14 días naturales anteriores al día visible; los días sin registros no se muestran.
- Q: ¿"Copiar de otro día" muestra solo comidas del mismo tipo que el destino o todas? → A: Todas las comidas con entradas, agrupadas por día; las del mismo tipo que el destino salen primero.
- Q: ¿En qué orden se muestra la pestaña de favoritos? → A: Por último uso, el más reciente primero; los nunca usados al final, en orden alfabético.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Añadir desde recientes (Priority: P1)

Al añadir a una comida, el usuario ve primero los alimentos que ha registrado recientemente, con la
última cantidad usada, y añade uno con un toque.

**Why this priority**: la mayoría de la gente come cosas parecidas cada día; es el mayor ahorro de
tiempo.

**Independent Test**: registrar varios alimentos, abrir "añadir" en otra comida y añadir uno de
recientes con un toque.

**Acceptance Scenarios**:

1. **Given** alimentos registrados antes, **When** el usuario abre "añadir" en una comida,
   **Then** ve sus recientes, los más recientes primero, con la última cantidad usada.
2. **Given** la lista de recientes, **When** toca "añadir" en uno, **Then** se crea la entrada con
   esa cantidad sin pasos adicionales.
3. **Given** la lista de recientes, **When** toca el alimento (no el botón de añadir rápido),
   **Then** puede cambiar la cantidad antes de añadir.
4. **Given** un usuario sin registros, **When** abre "añadir", **Then** ve un mensaje que explica
   que aquí aparecerán sus recientes.

---

### User Story 2 - Favoritos (Priority: P2)

El usuario marca alimentos como favoritos y los encuentra en una pestaña propia para añadirlos con
un toque.

**Why this priority**: complementa a recientes para lo habitual que no se come a diario.

**Independent Test**: marcar y desmarcar favoritos y añadir desde la pestaña de favoritos.

**Acceptance Scenarios**:

1. **Given** un alimento en búsqueda, recientes o en una entrada, **When** el usuario lo marca como
   favorito, **Then** aparece en su lista de favoritos.
2. **Given** la lista de favoritos, **When** toca "añadir" en uno, **Then** se crea la entrada con
   la última cantidad usada (o 100 g/ml, o una ración si nunca lo usó).
3. **Given** un favorito, **When** lo desmarca, **Then** desaparece de la lista.

---

### User Story 3 - Copiar una comida de otro día (Priority: P2)

El usuario elige una comida de otro día (por ejemplo, el desayuno de ayer) y la duplica en una
comida del día que está viendo.

**Why this priority**: resuelve en un paso las comidas que se repiten completas.

**Independent Test**: copiar el desayuno de ayer al de hoy y comprobar que se duplican todas las
entradas sin alterar las de ayer.

**Acceptance Scenarios**:

1. **Given** una comida del día visible, **When** el usuario elige "copiar de otro día", **Then** ve
   los últimos 14 días anteriores con sus comidas y su contenido, el más reciente primero, con las
   del mismo tipo que la comida destino primero dentro de cada día.
2. **Given** que elige el desayuno de ayer, **When** confirma, **Then** todas sus entradas se añaden
   al desayuno del día visible y el resumen se actualiza.
3. **Given** que la comida destino ya tiene entradas, **When** copia, **Then** las entradas copiadas
   se añaden a las existentes sin borrarlas.
4. **Given** la selección, **When** el usuario elige copiar a otra comida distinta (por ejemplo, la
   comida de ayer a la cena de hoy), **Then** se permite.
5. **Given** una copia hecha por error, **When** la deshace en los 5 segundos siguientes, **Then** se
   eliminan solo las entradas copiadas.

---

### Edge Cases

- **Alimento personalizado borrado** que está en recientes o favoritos: deja de aparecer en esas
  listas; las entradas ya registradas no cambian.
- **Copiar una comida que contiene un alimento personalizado editado**: la copia usa los valores
  actuales del alimento, no los de la entrada original. Si el alimento fue borrado, la copia
  conserva los valores de la entrada original.
- **Comida origen vacía**: no aparece como opción para copiar.
- **Muchos recientes**: se muestran los 30 últimos alimentos distintos.
- **Mismo alimento registrado varias veces**: aparece una sola vez en recientes, con la cantidad de
  su último uso.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar al usuario sus 30 últimos alimentos distintos registrados,
  ordenados por último uso, con la última cantidad usada. La lista es global: no se filtra por la
  comida (desayuno, cena…) desde la que se abre "añadir".
- **FR-002**: Los usuarios MUST poder añadir un alimento desde recientes o favoritos con un solo
  toque, usando la última cantidad, o abrirlo para ajustar la cantidad.
- **FR-003**: Los usuarios MUST poder marcar y desmarcar alimentos como favoritos desde la búsqueda,
  recientes y las entradas del diario.
- **FR-004**: Un favorito sin uso previo MUST añadirse con una ración si el alimento la tiene, o con
  100 g/ml si no.
- **FR-005**: Los usuarios MUST poder copiar todas las entradas de una comida de un día anterior a
  cualquier comida del día visible, añadiéndolas a las existentes. Solo se ofrecen los 14 días
  anteriores al día visible, el más reciente primero, y dentro de cada día todas las comidas con
  entradas; las del mismo tipo que la comida destino salen primero.
- **FR-006**: Las entradas copiadas MUST calcular sus valores con los datos actuales del alimento en
  la base (principio: valores siempre desde la base); si el alimento ya no existe, conservan los
  valores de la entrada original.
- **FR-007**: Los usuarios MUST poder deshacer un añadido rápido o una copia durante 5 segundos
  desde que se hace; pasado ese tiempo la opción desaparece.
- **FR-008**: Recientes y favoritos MUST ser propios de cada usuario e invisibles para otros.
- **FR-009**: Todas las pantallas MUST estar en español, en unidades métricas y cumplir WCAG 2.1 AA;
  cada botón de añadir rápido MUST tener una etiqueta para el lector de pantalla que nombre el
  alimento y la cantidad.
- **FR-010**: La lista de favoritos MUST ordenarse por último uso (el más reciente primero); los
  favoritos nunca usados van al final, en orden alfabético.

### Key Entities

- **Reciente**: vista derivada de las entradas del usuario (alimento, última cantidad, último uso);
  no requiere guardarse aparte.
- **Favorito**: alimento marcado por un usuario, con su fecha.
- **Entrada** (de 004): las copias son entradas nuevas e independientes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Añadir un alimento reciente o favorito lleva un toque desde la pantalla de añadir y
  menos de 5 segundos desde la pantalla principal.
- **SC-002**: Copiar una comida de otro día lleva menos de 15 segundos.
- **SC-003**: El 100% de las copias duplican todas las entradas de la comida origen sin modificarla.
- **SC-004**: 0 favoritos o recientes visibles para otros usuarios (verificado con pruebas).

## Assumptions

- "Copiar comida de otro día" copia una sola comida; copiar un día completo queda fuera.
- Los recientes incluyen alimentos registrados por cualquier método (búsqueda, código de barras,
  foto o copia).
- No hay "comidas guardadas" o plantillas con nombre (fuera de alcance; recetas fuera del MVP).
