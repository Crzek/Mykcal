# Feature Specification: Diario de comidas y resumen diario

**Feature Branch**: `004-diario-de-comidas`

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "004-diario-de-comidas: comidas fijas, entradas, resumen diario y edición de días pasados. Épica E5."

## Clarifications

### Session 2026-11-24

- Q: Si el usuario añade un alimento que ya está en esa comida del mismo día, ¿se suman o quedan
  entradas separadas? → A: Quedan dos entradas separadas, cada una con su cantidad.
- Q: Si una entrada se registró en raciones, ¿en qué unidad se edita su cantidad? → A: En la
  misma unidad del registro, con opción de cambiar a g/ml.
- Q: ¿Cuánto dura la opción de deshacer tras borrar una entrada? → A: 10 segundos.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver el resumen del día (Priority: P1)

Al abrir la app, el usuario ve la pantalla principal: el resumen del día (consumido, objetivo y
restante de calorías y macros) y las cinco comidas del día (desayuno, comida, merienda, cena y
picoteo) con lo registrado en cada una.

**Why this priority**: es la pantalla principal y responde a la pregunta central: cuánto me falta.

**Independent Test**: con un objetivo y algunas entradas registradas, abrir la app y comprobar que
consumido + restante = objetivo para cada valor.

**Acceptance Scenarios**:

1. **Given** un usuario con objetivo y sin entradas hoy, **When** abre la app, **Then** ve consumido
   0, objetivo completo como restante y las cinco comidas vacías.
2. **Given** entradas registradas hoy, **When** abre la app, **Then** ve calorías, proteína,
   carbohidratos y grasa consumidos, objetivo y restante, y el total de cada comida.
3. **Given** que ha superado un valor del objetivo, **When** ve el resumen, **Then** el restante se
   muestra como exceso (por ejemplo, "+150 kcal") de forma distinguible sin depender solo del color.
4. **Given** el resumen, **When** el usuario pide más detalle, **Then** ve también fibra y los
   7 micros con consumido y objetivo; los micros con algún dato faltante se marcan "incompleto".

---

### User Story 2 - Añadir un alimento a una comida (Priority: P1)

Desde una comida del día, el usuario busca o escanea un alimento, indica la cantidad (en gramos,
mililitros o raciones del envase) y lo añade. El resumen se actualiza al momento.

**Why this priority**: sin registrar no hay diario; es la acción más frecuente.

**Independent Test**: añadir un alimento genérico y uno envasado por raciones y comprobar que los
totales coinciden con los valores de la base multiplicados por la cantidad.

**Acceptance Scenarios**:

1. **Given** la comida "Desayuno" de hoy, **When** el usuario añade 150 g de un alimento con
   200 kcal/100 g, **Then** se crea una entrada de 300 kcal y el resumen se actualiza.
2. **Given** un envasado con ración de 30 g, **When** el usuario indica 2 raciones, **Then** la
   entrada se guarda como 60 g con sus valores.
3. **Given** el formulario de cantidad, **When** el usuario cambia la cantidad, **Then** ve los
   valores resultantes antes de guardar.
4. **Given** una cantidad 0, negativa o vacía, **When** intenta guardar, **Then** se rechaza con
   mensaje.

---

### User Story 3 - Editar y borrar entradas (Priority: P1)

El usuario cambia la cantidad de una entrada, la mueve a otra comida del mismo día o la borra.

**Why this priority**: los errores al registrar son frecuentes; sin corregir, el diario pierde
valor.

**Independent Test**: editar la cantidad, mover y borrar entradas y comprobar los totales.

**Acceptance Scenarios**:

1. **Given** una entrada, **When** el usuario cambia su cantidad, **Then** sus valores y los totales
   se recalculan.
2. **Given** una entrada registrada como 2 raciones de 30 g, **When** el usuario la edita, **Then**
   el formulario muestra "2 raciones" y le deja cambiar a gramos; al guardar se conserva la unidad
   elegida.
3. **Given** una entrada en "Comida", **When** la mueve a "Cena", **Then** cambia de comida y los
   totales por comida se actualizan.
4. **Given** una entrada, **When** la borra, **Then** desaparece y los totales se actualizan; la app
   permite deshacer durante 10 segundos.

---

### User Story 4 - Navegar y editar días pasados (Priority: P2)

El usuario cambia de día (anterior, siguiente o desde un calendario) y ve y edita el diario de
cualquier día pasado con el objetivo que tenía ese día.

**Why this priority**: permite registrar lo que se olvidó y revisar días anteriores, pero el día de
hoy es lo esencial.

**Independent Test**: ir a un día pasado, añadir y editar entradas y comprobar que el día de hoy
no cambia.

**Acceptance Scenarios**:

1. **Given** la pantalla del día, **When** el usuario va al día anterior, **Then** ve el resumen y
   las comidas de ese día.
2. **Given** un día pasado, **When** añade, edita o borra entradas, **Then** los cambios se guardan
   en ese día y no afectan a otros.
3. **Given** un día pasado, **When** se muestra el resumen, **Then** se compara con el objetivo
   vigente ese día, no con el actual.
4. **Given** un día futuro, **When** el usuario intenta ir a él, **Then** no puede registrar en días
   futuros.

---

### Edge Cases

- **Cambio de objetivo a mitad de día**: el día de hoy usa el objetivo vigente al terminar el día;
  los días pasados conservan el suyo.
- **Alimento personalizado editado o borrado después de registrarlo**: la entrada mantiene sus
  valores y su nombre originales.
- **Día anterior al alta del usuario**: no se puede navegar a fechas anteriores a su alta.
- **Cambio de día con la app abierta a medianoche**: al volver a la pantalla principal se muestra
  el día nuevo.
- **Zona horaria**: el día se determina por la fecha local del móvil del usuario.
- **Sin conexión**: al añadir, editar o borrar se avisa y la cantidad que el usuario estaba
  escribiendo no se pierde; el diario no cambia hasta que el servidor confirma.
- **Mismo alimento dos veces en una comida**: se crean entradas separadas, cada una con su
  cantidad y su copia de valores; nunca se fusionan.
- **Cantidades muy grandes** (más de 5.000 g o ml en una entrada): se pide confirmación. Por
  encima de 10.000 g o ml (o de 100 raciones) no se admite.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cada día del diario MUST tener cinco comidas fijas: desayuno, comida, merienda, cena y
  picoteo, en ese orden.
- **FR-002**: Los usuarios MUST poder añadir a una comida un alimento (genérico, envasado o
  personalizado) con una cantidad en gramos o mililitros, o en raciones cuando el alimento tenga
  tamaño de ración. La cantidad MUST ser mayor que 0 y no superar 10.000 g/ml ni 100 raciones.
- **FR-003**: Los valores de cada entrada MUST calcularse a partir de los valores por 100 g/ml del
  alimento en la base y la cantidad, nunca introducirse a mano en la entrada.
- **FR-004**: Cada entrada MUST guardar una copia de los valores nutricionales y el nombre del
  alimento en el momento de registrarla, de modo que cambios posteriores del alimento no la alteren.
- **FR-005**: Los usuarios MUST poder editar la cantidad (en la unidad con que se registró la
  entrada, g/ml o raciones, con opción de cambiar a g/ml), mover una entrada a otra comida del mismo
  día y borrarla, con opción de deshacer el borrado durante 10 segundos.
- **FR-006**: El resumen diario MUST mostrar, para calorías, proteína, carbohidratos y grasa:
  consumido, objetivo y restante (o exceso).
- **FR-007**: El detalle del resumen MUST mostrar fibra y los 7 micros con consumido y objetivo;
  para el sodio (un máximo) se indica lo que queda hasta el límite.
- **FR-008**: Un total MUST marcarse como "incompleto" cuando alguna entrada del día no tenga dato
  de ese nutriente.
- **FR-009**: Cada comida MUST mostrar sus entradas y su total de calorías y macros.
- **FR-010**: Los usuarios MUST poder ver y editar cualquier día desde su alta hasta hoy; no se
  admiten días futuros.
- **FR-011**: Cada día MUST compararse con el objetivo vigente en ese día.
- **FR-012**: La pantalla principal MUST ser el resumen del día de hoy con sus comidas.
- **FR-013**: Los usuarios MUST ver y modificar solo su propio diario.
- **FR-014**: Todas las pantallas MUST estar en español, en unidades métricas y cumplir WCAG 2.1 AA;
  el exceso sobre el objetivo MUST indicarse con texto o icono además del color.

### Key Entities

- **Día**: fecha del diario de un usuario. Tiene asociado el objetivo vigente en esa fecha.
- **Comida**: desayuno, comida, merienda, cena o picoteo de un día.
- **Entrada**: un alimento con su cantidad (g/ml y, si aplica, raciones) dentro de una comida, con
  la copia de nombre y valores nutricionales calculados al registrarla y su fecha de creación.
- **Objetivo diario** (de 002): se versiona para saber cuál regía cada día.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario añade un alimento buscado a una comida en menos de 30 segundos.
- **SC-002**: En el 100% de los casos de prueba, consumido + restante = objetivo para cada valor y
  los totales coinciden con la suma de entradas.
- **SC-003**: El resumen se actualiza al instante tras añadir, editar o borrar una entrada
  (percibido sin espera por el usuario).
- **SC-004**: El 100% de las entradas conservan sus valores originales tras editar o borrar el
  alimento del que provienen.
- **SC-005**: 0 accesos a diarios de otros usuarios (verificado con pruebas automáticas).

## Assumptions

- El registro por foto se integra en la feature 006 y el registro rápido en la 005; aquí el
  alimento llega por búsqueda o código de barras (de 003).
- El objetivo de un día pasado es el último objetivo vigente en esa fecha.
- Si el usuario consulta un día en que aún no tenía objetivo (entre su alta y el primer objetivo
  calculado), se compara con su primer objetivo.
- No hay comidas personalizables ni horas de comida; solo las cinco fijas.
- Las calorías del ejercicio no se suman al objetivo (fase posterior).
