# Feature Specification: Peso y recálculo del objetivo

**Feature Branch**: `007-peso-y-recalculo`

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "007-peso-y-recalculo: registro de peso, gráfica y propuesta de recálculo. Épica E9."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar el peso (Priority: P1)

El usuario anota su peso del día cuando quiere. Puede corregir o borrar registros.

**Why this priority**: sin registros de peso no hay seguimiento ni recálculo.

**Independent Test**: registrar, corregir y borrar pesos y comprobar la lista.

**Acceptance Scenarios**:

1. **Given** la pantalla de peso, **When** el usuario introduce 78,4 kg para hoy, **Then** se guarda
   el registro de hoy.
2. **Given** un registro de hoy, **When** introduce otro peso para hoy, **Then** sustituye al
   anterior (un registro por día).
3. **Given** un día pasado sin registro, **When** el usuario elige esa fecha e introduce un peso,
   **Then** se guarda en esa fecha.
4. **Given** un registro, **When** lo edita o lo borra, **Then** se aplica y la gráfica se
   actualiza.
5. **Given** un peso fuera de 30–300 kg, **When** intenta guardarlo, **Then** se rechaza con el
   rango válido.

---

### User Story 2 - Ver la gráfica de peso (Priority: P2)

El usuario ve la evolución de su peso en una gráfica con los registros diarios y la media semanal,
en distintos periodos.

**Why this priority**: permite saber si el objetivo funciona.

**Independent Test**: con registros de varias semanas, comprobar la gráfica en cada periodo y su
alternativa textual.

**Acceptance Scenarios**:

1. **Given** registros de peso, **When** el usuario abre la gráfica, **Then** ve los pesos diarios y
   la línea de media semanal de los últimos 30 días.
2. **Given** la gráfica, **When** cambia a 90 días o a todo, **Then** se ajusta al periodo.
3. **Given** la gráfica, **When** se usa con lector de pantalla, **Then** se ofrece un resumen
   textual (peso actual, media semanal y variación en el periodo) y la lista de registros.
4. **Given** menos de 2 registros, **When** abre la gráfica, **Then** ve un mensaje que explica que
   necesita más registros.

---

### User Story 3 - Propuesta de recálculo del objetivo (Priority: P1)

Cuando la media semanal de peso varía más de un 2% respecto al peso usado en el último cálculo del
objetivo, la app propone recalcular. El usuario acepta (se recalcula con la media semanal) o lo
ignora.

**Why this priority**: mantiene el objetivo ajustado a la realidad del usuario sin que tenga que
acordarse.

**Independent Test**: con registros preparados que superen y que no superen el umbral, comprobar
que la propuesta aparece solo cuando corresponde y que aceptar e ignorar funcionan.

**Acceptance Scenarios**:

1. **Given** un objetivo calculado con 80 kg y una media semanal de 78,2 kg (−2,25%) con al menos
   3 registros en los últimos 7 días, **When** el usuario abre la app, **Then** se le propone
   recalcular el objetivo mostrando el objetivo actual y el nuevo.
2. **Given** una media semanal de 78,6 kg (−1,75%), **When** abre la app, **Then** no hay propuesta.
3. **Given** un único registro de 76 kg en los últimos 7 días, **When** abre la app, **Then** no hay
   propuesta (oscilaciones diarias no cuentan).
4. **Given** la propuesta, **When** el usuario acepta, **Then** el objetivo se recalcula con las
   reglas de 002 usando la media semanal como peso, y ese peso pasa a ser el peso usado en el
   cálculo.
5. **Given** la propuesta, **When** el usuario la ignora, **Then** el objetivo no cambia y no se
   vuelve a proponer durante 7 días.
6. **Given** un objetivo editado a mano, **When** se cumple el umbral, **Then** la propuesta avisa de
   que aceptar sustituirá sus valores editados.

---

### Edge Cases

- **Huecos en los registros**: la media semanal usa solo los registros existentes de los últimos
  7 días (incluido hoy); con menos de 3 no se calcula media para el recálculo.
- **Registro de un día pasado** que cambia la media: la comprobación se repite al guardar.
- **Borrar el registro del onboarding**: se permite; el peso usado en el cálculo sigue guardado con
  el objetivo.
- **Variación muy grande** (más de un 10% en una semana): la propuesta se muestra igual, con un aviso
  de revisar si hay un registro erróneo.
- **Días pasados del diario**: el recálculo solo afecta al objetivo desde hoy; los días anteriores
  mantienen su objetivo.
- **Sin conexión**: se avisa y el peso escrito se conserva en pantalla.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Los usuarios MUST poder registrar su peso en kg con un decimal (30–300 kg) en
  cualquier fecha desde su alta hasta hoy, con un registro por día.
- **FR-002**: Los usuarios MUST poder editar y borrar sus registros de peso.
- **FR-003**: La app MUST mostrar una gráfica con los pesos diarios y la media semanal, con periodos
  de 30 días, 90 días y todo, y una alternativa textual accesible.
- **FR-004**: La media semanal MUST ser la media de los registros de los últimos 7 días (incluido
  hoy) y solo se usa para el recálculo con al menos 3 registros.
- **FR-005**: El sistema MUST proponer recalcular el objetivo cuando la media semanal difiera más de
  un 2% del peso usado en el último cálculo.
- **FR-006**: Si el usuario acepta, el objetivo MUST recalcularse con las reglas de la feature 002
  usando la media semanal como peso, que pasa a ser el peso usado en el cálculo; el objetivo nuevo
  rige desde hoy.
- **FR-007**: Si el usuario ignora la propuesta, el sistema MUST NOT volver a proponerla durante
  7 días.
- **FR-008**: Un objetivo editado a mano MUST NOT recalcularse sin confirmación explícita, avisando
  de que se sustituirán sus valores.
- **FR-009**: El cálculo de la media y del umbral MUST ser determinista y estar cubierto por pruebas
  con casos conocidos (justo por encima y por debajo del 2%, menos de 3 registros, huecos).
- **FR-010**: Los usuarios MUST ver y modificar solo sus propios registros de peso.
- **FR-011**: Todas las pantallas MUST estar en español, en kg y cumplir WCAG 2.1 AA.

### Key Entities

- **Registro de peso**: peso de un usuario en una fecha (uno por día).
- **Media semanal**: valor derivado de los registros de los últimos 7 días.
- **Propuesta de recálculo**: momento en que se propuso, objetivo actual y nuevo, y respuesta del
  usuario (aceptada o ignorada, con fecha).
- **Objetivo diario** (de 002): guarda el peso usado en su cálculo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Registrar el peso lleva menos de 10 segundos desde la pantalla principal.
- **SC-002**: El 100% de los casos de prueba del umbral (por encima, por debajo, menos de 3
  registros) dan el resultado esperado.
- **SC-003**: 0 propuestas de recálculo provocadas por un único registro aislado.
- **SC-004**: El 100% de los objetivos editados a mano permanecen sin cambios si el usuario no
  confirma.

## Assumptions

- El peso del onboarding (002) es el primer registro y el primer peso usado en el cálculo.
- La comprobación del umbral se hace al registrar un peso y al abrir la app.
- No hay sincronización con básculas ni con la plataforma de salud del móvil (fase posterior).
- No se muestran objetivos de peso ni previsiones.
