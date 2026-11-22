# Feature Specification: Clave de IA y registro por foto

**Feature Branch**: `006-clave-ia-y-foto`

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "006-clave-ia-y-foto: guía y guardado cifrado de la clave, análisis de foto, corrección, cruce con la base y borradores. Épica E6."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configurar la clave de IA (Priority: P1)

El usuario sigue una guía paso a paso dentro de la app para obtener su clave personal del
proveedor de IA y la pega. La app comprueba que funciona y la guarda. Puede hacerlo al final del
onboarding o más tarde desde los ajustes, y también cambiarla o quitarla.

**Why this priority**: sin clave no hay análisis de foto; cada usuario paga su propio uso.

**Independent Test**: pegar una clave válida (queda configurada), una inválida (se rechaza con
mensaje) y quitarla (la foto vuelve a aparecer desactivada).

**Acceptance Scenarios**:

1. **Given** el final del onboarding, **When** el usuario llega al paso de la clave, **Then** ve la
   guía y puede pegar su clave u omitir el paso.
2. **Given** una clave válida, **When** el usuario la guarda, **Then** el sistema comprueba que
   funciona, la guarda y muestra "Clave configurada" con la fecha, sin volver a mostrar la clave.
3. **Given** una clave inválida, **When** intenta guardarla, **Then** no se guarda y se muestra un
   mensaje claro de la causa.
4. **Given** una clave configurada, **When** el usuario la sustituye o la quita desde ajustes,
   **Then** se aplica de inmediato; sin clave la función de foto queda desactivada.
5. **Given** cualquier pantalla o respuesta del servidor, **When** se inspecciona, **Then** nunca
   contiene la clave ni parte de ella.

---

### User Story 2 - Registrar un plato con una foto (Priority: P1)

El usuario elige la comida del día, hace una foto del plato y, opcionalmente, añade una descripción
y los gramos totales. La IA propone una lista de alimentos con sus gramos estimados. El usuario
corrige alimentos y gramos y guarda. Los valores nutricionales salen de la base de alimentos.

**Why this priority**: es la función diferencial de la app y la más rápida para platos completos.

**Independent Test**: con respuestas de la IA guardadas, fotografiar un plato, corregir un gramaje,
sustituir un alimento y guardar; comprobar que las entradas usan valores de la base.

**Acceptance Scenarios**:

1. **Given** un usuario con clave en una comida del día, **When** hace una foto y la envía,
   **Then** ve un indicador de progreso y después la lista propuesta de alimentos con sus gramos.
2. **Given** la propuesta, **When** se muestra, **Then** cada alimento aparece ya emparejado con un
   alimento de la base (el más parecido), con sus kcal calculadas, y se indica cuáles no tienen
   pareja.
3. **Given** la propuesta, **When** el usuario cambia gramos, sustituye un alimento por otro de la
   base, añade uno o quita otro, **Then** los totales se recalculan con los valores de la base.
4. **Given** un alimento propuesto sin pareja en la base, **When** el usuario lo revisa, **Then**
   puede elegir uno parecido de la base o crear un alimento personalizado; no puede guardarse sin
   resolverlo o quitarlo.
5. **Given** la propuesta revisada, **When** el usuario pulsa guardar, **Then** se crean las
   entradas en la comida elegida y el resumen se actualiza. Nada se guarda en el diario antes de
   esta confirmación.
6. **Given** el análisis terminado (guardado o no), **When** se comprueba el servidor, **Then** la
   foto no está guardada en él; solo queda en el móvil del usuario.

---

### User Story 3 - Borradores cuando la IA falla (Priority: P1)

Si el análisis no se puede hacer o no sirve, la foto queda como borrador con la causa explicada y
el usuario puede reintentar o continuar a mano buscando los alimentos.

**Why this priority**: la IA fallará (clave, cuota, respuesta inválida); el usuario no debe perder
la comida.

**Independent Test**: simular clave revocada, cuota agotada, respuesta inválida y plato no
reconocido; comprobar en cada caso el borrador, el mensaje y la continuación manual.

**Acceptance Scenarios**:

1. **Given** una clave inválida o revocada, **When** se analiza, **Then** la foto queda como
   borrador, el mensaje indica que la clave no es válida y ofrece ir a cambiarla.
2. **Given** la cuota del proveedor agotada, **When** se analiza, **Then** la foto queda como
   borrador y el mensaje indica que es un límite de su cuenta del proveedor, no de la app.
3. **Given** una respuesta inválida o un plato no reconocido, **When** se analiza, **Then** la foto
   queda como borrador y se ofrece continuar a mano.
4. **Given** un borrador, **When** el usuario lo abre, **Then** ve la foto, la comida y el día
   elegidos, y puede reintentar el análisis o añadir alimentos a mano desde la búsqueda.
5. **Given** un borrador completado a mano o descartado, **When** termina, **Then** desaparece de
   la lista de borradores.

---

### User Story 4 - Foto desactivada sin clave (Priority: P2)

Un usuario sin clave ve la opción de foto desactivada con un acceso a la guía; el resto de la app
funciona igual.

**Why this priority**: garantiza que la app sirve sin IA (principio III).

**Independent Test**: sin clave, comprobar que la foto aparece desactivada con acceso a la guía y
que búsqueda, código de barras y registro rápido funcionan.

**Acceptance Scenarios**:

1. **Given** un usuario sin clave, **When** abre "añadir" en una comida, **Then** la opción de foto
   aparece desactivada con un texto que explica por qué y un acceso a la guía.
2. **Given** un usuario sin clave, **When** usa cualquier otra función, **Then** funciona igual que
   con clave.

---

### Edge Cases

- **El análisis tarda demasiado** (más de 60 segundos): se cancela y la foto queda como borrador
  con opción de reintentar.
- **Sin conexión al enviar la foto**: no se envía; queda como borrador y se avisa.
- **El usuario sale de la pantalla durante el análisis**: al terminar, el resultado queda como
  propuesta pendiente o borrador y se puede retomar.
- **Gramos totales indicados por el usuario**: se pasan a la IA como pista; la suma propuesta puede
  diferir y el usuario la corrige.
- **La IA propone un alimento varias veces**: se muestra una sola vez con los gramos sumados.
- **Gramos propuestos absurdos** (0 o más de 2.000 g para un alimento): se muestran marcados para
  revisión.
- **Cambio de móvil**: los borradores y las fotos antiguas se pierden; las entradas guardadas se
  conservan.
- **Permiso de cámara denegado**: se explica por qué se necesita y se permite elegir una foto de la
  galería.
- **Foto que no es comida**: se trata como plato no reconocido.

## Requirements *(mandatory)*

### Functional Requirements

**Clave de IA**

- **FR-001**: La app MUST incluir una guía paso a paso para que el usuario obtenga su clave del
  proveedor de IA, accesible desde el onboarding, los ajustes y la opción de foto desactivada.
- **FR-002**: Los usuarios MUST poder guardar, sustituir y quitar su clave; al guardarla, el sistema
  MUST comprobar que es válida y rechazarla con un mensaje claro si no lo es.
- **FR-003**: La clave MUST guardarse cifrada con una clave maestra que no está en la base de datos.
- **FR-004**: Ninguna respuesta del servidor ni pantalla de la app MUST contener la clave ni parte
  de ella; la app solo sabe si hay clave configurada y desde cuándo.
- **FR-005**: Las llamadas al proveedor de IA MUST hacerse desde el servidor con la clave del propio
  usuario.

**Análisis de foto**

- **FR-006**: Los usuarios con clave MUST poder hacer una foto (o elegirla de la galería) para una
  comida de un día, con descripción y gramos totales opcionales.
- **FR-007**: La IA MUST devolver solo una lista de alimentos con gramos estimados; la respuesta
  MUST validarse contra un formato estructurado y tratarse como fallo si no lo cumple.
- **FR-008**: Cada alimento propuesto MUST emparejarse con el alimento más parecido de la base
  (personalizados del usuario incluidos) y mostrarse con los valores de la base; los no emparejados
  se marcan.
- **FR-009**: Los valores nutricionales MUST salir siempre de la base de alimentos, nunca de la IA.
- **FR-010**: Los usuarios MUST poder cambiar gramos, sustituir, añadir y quitar alimentos de la
  propuesta antes de guardar, y crear un alimento personalizado desde ella.
- **FR-011**: Nada de la propuesta MUST guardarse en el diario sin la confirmación explícita del
  usuario.
- **FR-012**: Las fotos MUST procesarse en memoria en el servidor y descartarse tras el análisis;
  0 fotos guardadas en el servidor.
- **FR-013**: El análisis MUST pasar por los estados pendiente → propuesto → guardado | borrador.

**Borradores**

- **FR-014**: Cuando el análisis falle (clave inválida o revocada, cuota agotada, respuesta
  inválida, plato no reconocido, tiempo agotado o sin conexión), la foto MUST quedar como borrador
  con un mensaje que explique la causa y la acción posible.
- **FR-015**: Los usuarios MUST poder ver sus borradores, reintentar el análisis, completarlos a
  mano o descartarlos.

**Sin clave**

- **FR-016**: Sin clave, la opción de foto MUST aparecer desactivada con explicación y acceso a la
  guía; el resto de funciones MUST funcionar igual.

**Observabilidad**

- **FR-017**: Cada llamada al proveedor de IA MUST registrarse con usuario, fecha, resultado y causa
  del fallo si la hay, sin la foto, la respuesta ni la clave.

**Diseño y pruebas**

- **FR-018**: El acceso al proveedor de IA MUST quedar aislado de forma que pueda añadirse otro
  proveedor sin cambiar el resto del sistema.
- **FR-019**: Las pruebas MUST NOT usar claves reales ni llamar al proveedor: usan respuestas
  guardadas que cubren éxito, clave inválida, cuota agotada, respuesta inválida y plato no
  reconocido.
- **FR-020**: Todas las pantallas MUST estar en español, en unidades métricas y cumplir WCAG 2.1 AA.

### Key Entities

- **Clave de IA**: clave del proveedor de IA de un usuario, cifrada. Atributos visibles: si existe,
  proveedor y fecha de configuración.
- **Análisis de foto**: petición de análisis de un usuario para una comida y un día, con
  descripción y gramos opcionales; estado (pendiente, propuesto, guardado, borrador) y causa del
  fallo si la hay.
- **Propuesta**: lista de alimentos sugeridos con gramos y su pareja en la base.
- **Borrador de foto**: análisis no completado, con la foto en el móvil del usuario.
- **Registro de uso de la IA**: usuario, fecha, resultado y causa del fallo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario registra un plato por foto, con una corrección, en menos de 1 minuto
  desde que abre la cámara.
- **SC-002**: El 100% de los fallos del análisis dejan un borrador con un mensaje que nombra la
  causa.
- **SC-003**: 0 fotos guardadas en el servidor y 0 respuestas del servidor que contengan claves
  (verificado con pruebas automáticas).
- **SC-004**: El 100% de las entradas creadas por foto tienen valores que coinciden con la base de
  alimentos para los gramos confirmados.
- **SC-005**: El 100% de las llamadas a la IA quedan registradas con usuario y resultado.
- **SC-006**: Al menos el 70% de los alimentos propuestos en un conjunto de 20 platos habituales
  quedan emparejados con un alimento correcto de la base sin intervención del usuario.

## Assumptions

- El proveedor de IA del MVP es Google Gemini; el modelo concreto se decide en el plan (pregunta
  abierta 13).
- Los borradores viven en el móvil del usuario junto con su foto; si cambia de móvil, se pierden.
- No hay objetivo de tiempo de respuesta del análisis más allá del límite de 60 segundos para
  pasar a borrador (pregunta abierta 10).
- Si el usuario no da su consentimiento (002), no llega a esta feature.
- El usuario es responsable del coste y de las condiciones de su cuenta en el proveedor.
