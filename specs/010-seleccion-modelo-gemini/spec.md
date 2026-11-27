# Feature Specification: Selección dinámica del modelo de Gemini

**Feature Branch**: `010-seleccion-modelo-gemini`

**Created**: 2026-11-26

**Status**: Draft

**Input**: User description: "Selección dinámica del modelo de Gemini. Hoy el modelo de IA se fija con una variable de entorno (y un valor por defecto en el código) y el mismo modelo se usa para validar la clave y analizar fotos. Los modelos de Gemini cambian: `gemini-2.0-flash` se apagó el 1 de junio de 2026 y `gemini-3.8-flash` devolvió 503 por alta demanda, lo que hacía fallar el guardado de la clave con «No se ha podido comprobar la clave ahora». Queremos que la app descubra en tiempo de ejecución qué modelos hay disponibles para la clave de la persona, elija uno adecuado para analizar fotos y siga funcionando cuando un modelo se retire, sin cambiar código ni variables de entorno. Debe tener en cuenta la capa gratuita, tolerar saturación temporal probando el siguiente candidato, no consultar el listado en cada análisis y registrar el modelo elegido y el motivo de los fallos sin registrar claves ni cuerpos. La variable de entorno pasa a ser una preferencia opcional. Mejora de la 006-clave-ia-y-foto."

## Clarifications

### Session 2026-11-26

- Q: Si un modelo responde «límite alcanzado» (429), ¿se prueba el siguiente candidato o se avisa de inmediato? → A: Se prueba el siguiente candidato, igual que ante saturación; si todos dan 429 se muestra «límite alcanzado».
- Q: ¿Cómo decide la app qué modelos son «rápidos y económicos» sin preferencia? → A: Por nombre: se aceptan `flash` y `flash-lite`; se excluyen `pro`, `ultra` y variantes experimentales; orden `lite` primero, luego `flash`, y dentro de cada grupo el más nuevo.
- Q: ¿Cuánto dura el listado en caché y cuánto se evita un modelo saturado? → A: Listado 24 horas; modelo saturado evitado 3 minutos.
- Q: ¿Cuánto tiempo puede gastar un solo candidato antes de pasar al siguiente? → A: 20 s por candidato; el total del análisis sigue en 55 s.
- Q: ¿Dónde se guardan el listado en caché y los modelos evitados? → A: En memoria del proceso, indexado por huella (hash) de la clave; nunca la clave en claro ni en disco; se pierde al reiniciar.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El análisis de fotos sigue funcionando cuando un modelo desaparece (Priority: P1)

Una persona con su clave de IA hace una foto de su plato. Aunque el modelo que la app usaba el mes
pasado ya no exista, el análisis se completa igual con otro modelo disponible para su clave, sin que
Erick haya tocado código ni configuración.

**Why this priority**: es el fallo que originó esta feature. Un modelo retirado deja la función de
foto rota para todos hasta que alguien se entera, averigua la causa y redespliega.

**Independent Test**: simular que el modelo preferido ya no figura en el listado de la cuenta,
analizar una foto y comprobar que se completa con otro modelo válido y que el registro dice cuál
se eligió.

**Acceptance Scenarios**:

1. **Given** un modelo preferido que ya no existe para la clave de la persona, **When** analiza una
   foto, **Then** el análisis se completa con otro modelo disponible que admite imágenes.
2. **Given** que nunca se ha configurado ninguna preferencia de modelo, **When** una persona analiza
   una foto, **Then** el análisis funciona igualmente con el mejor modelo disponible.
3. **Given** un análisis hecho con un modelo sustituto, **When** Erick revisa el registro, **Then**
   ve qué modelo se usó y que fue por sustitución, sin ver la clave ni la foto.

---

### User Story 2 - Una saturación temporal no impide analizar (Priority: P1)

Un modelo responde «alta demanda» (503) en el momento de analizar. La app prueba automáticamente el
siguiente candidato y la persona obtiene su resultado sin tener que reintentar a mano.

**Why this priority**: es el segundo fallo observado (`gemini-3.8-flash` en 503). Los modelos más
nuevos son los que más se saturan, justo los que se preferirían.

**Independent Test**: simular que el primer candidato responde 503 y el segundo funciona; analizar y
comprobar que el resultado llega y que el registro refleja ambos intentos.

**Acceptance Scenarios**:

1. **Given** un primer candidato saturado y un segundo disponible, **When** se analiza una foto,
   **Then** el resultado llega usando el segundo, dentro del tiempo máximo de espera del análisis.
2. **Given** todos los candidatos saturados, **When** se analiza una foto, **Then** la persona ve el
   aviso de que el proveedor no responde y puede continuar a mano, como ya ocurre hoy.
3. **Given** un modelo que se satura a menudo, **When** se repiten los análisis, **Then** la app no
   insiste en él en cada petición durante 3 minutos tras una saturación.
4. **Given** un primer candidato sin cuota (429) y un segundo disponible, **When** se analiza una
   foto, **Then** el resultado llega usando el segundo; si todos dan 429, la persona ve el aviso de
   límite alcanzado.

---

### User Story 3 - Preferir modelos con capa gratuita (Priority: P2)

Erick, que usa la capa gratuita, puede indicar una lista ordenada de modelos preferidos. La app usa
el primero de esa lista que esté disponible y solo si ninguno lo está recurre a otro modelo
compatible.

**Why this priority**: el listado de modelos no dice cuáles son gratuitos, así que Erick es quien
decide qué conviene. Sin esto, la app podría elegir un modelo de pago sin que nadie lo note.

**Independent Test**: configurar una lista de preferencia con dos modelos, comprobar que se usa el
primero disponible, luego retirar ese del listado y comprobar que pasa al segundo.

**Acceptance Scenarios**:

1. **Given** una lista de preferencia con varios modelos disponibles, **When** se analiza una foto,
   **Then** se usa el primero de la lista.
2. **Given** que ningún modelo de la lista está disponible, **When** se analiza una foto, **Then** se
   elige un modelo compatible fuera de la lista y el registro avisa de que la preferencia no se pudo
   cumplir.
3. **Given** que Erick no define preferencia, **When** se elige modelo, **Then** se prefieren los
   modelos rápidos y económicos frente a los de mayor coste.

---

### User Story 4 - Guardar la clave nunca depende de un modelo (Priority: P2)

Al guardar la clave, la app solo comprueba que la clave es válida. No depende de que ningún modelo
concreto esté operativo en ese momento.

**Why this priority**: ya está corregido en código (la comprobación lista modelos en vez de generar).
Se recoge aquí para que quede como requisito y no se pierda en futuros cambios.

**Independent Test**: con todos los modelos de análisis saturados, guardar una clave válida y
comprobar que se acepta.

**Acceptance Scenarios**:

1. **Given** una clave válida y los modelos saturados, **When** la persona la guarda, **Then** se
   acepta.
2. **Given** una clave mal escrita, **When** la persona la guarda, **Then** se rechaza con el aviso de
   clave no válida.

---

### User Story 5 - Diagnosticar fallos sin adivinar (Priority: P3)

Cuando algo falla con el proveedor, Erick puede ver en el registro por qué: modelo probado, código de
respuesta y motivo, sin ningún dato sensible.

**Why this priority**: encontrar la causa del fallo original costó varias rondas porque el registro
solo decía «proveedor no disponible».

**Independent Test**: provocar un fallo de cada tipo (modelo inexistente, saturación, red caída,
clave inválida) y comprobar que cada uno queda registrado de forma distinguible.

**Acceptance Scenarios**:

1. **Given** un fallo del proveedor, **When** Erick revisa el registro, **Then** distingue modelo no
   encontrado, saturación, caída de red y tiempo agotado.
2. **Given** cualquier entrada de registro, **When** se inspecciona, **Then** no contiene la clave,
   la foto, la respuesta de la IA ni el contenido de ningún mensaje del proveedor.

---

### Edge Cases

- El listado de modelos no se puede obtener (red caída, tiempo agotado): se usa el último listado
  conocido; si no hay ninguno, se intenta la preferencia configurada tal cual y, si falla, la persona
  ve el aviso habitual de proveedor no disponible.
- El listado devuelve modelos que no admiten imágenes o no generan texto: se descartan.
- El listado solo contiene modelos de pago, o ninguno compatible: el análisis falla con un aviso
  claro de que no hay modelo utilizable para esa clave, sin inventar uno.
- Una clave pierde acceso a un modelo entre el listado en caché y el análisis (404): se descarta ese
  modelo, se refresca el listado y se prueba el siguiente.
- Dos personas con claves de proyectos distintos pueden ver modelos distintos: el listado nunca se
  comparte entre claves.
- El listado en caché caduca: el siguiente análisis lo vuelve a obtener sin que la persona note
  retraso apreciable.
- La preferencia configurada contiene un modelo mal escrito o que nunca existió: se ignora con un
  aviso en el registro y se continúa con el resto.
- La clave de la persona se elimina o cambia: su listado en caché deja de usarse.
- Un modelo sustituto devuelve el formato de respuesta esperado: la respuesta se valida igual que
  siempre; si no es válida se trata como fallo, no se acepta.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Al analizar una foto, el sistema MUST averiguar qué modelos están disponibles para la
  clave de la persona y elegir uno que genere texto a partir de imágenes, sin depender de un nombre
  de modelo fijo en el código.
- **FR-002**: Si el modelo preferido deja de existir o deja de estar disponible, el sistema MUST
  continuar con otro modelo compatible sin intervención manual ni redespliegue.
- **FR-003**: Si un candidato responde con saturación temporal (503) o límite alcanzado (429), el
  sistema MUST probar el siguiente candidato dentro del tiempo máximo de espera del análisis, que
  MUST NOT ampliarse. Cada candidato dispone como máximo de 20 s; si se agota (o queda menos tiempo
  total), se pasa al siguiente con el tiempo restante. Si todos los candidatos responden 429, la persona ve el aviso de límite
  alcanzado; si hay mezcla de 429 y 503, se muestra el de límite alcanzado.
- **FR-004**: El sistema MUST aceptar una lista ordenada y opcional de modelos preferidos; MUST usar
  el primero disponible y recurrir a otro compatible solo si ninguno lo está.
- **FR-005**: Sin lista de preferencia, el sistema MUST preferir modelos rápidos y económicos y MUST
  NOT elegir de forma automática modelos de gama alta o de coste superior si existe una alternativa
  económica compatible. «Económico» se decide por nombre: se aceptan los que contienen `flash` o
  `flash-lite`; se excluyen `pro`, `ultra` y variantes experimentales (`exp`). Orden: `flash-lite` primero, luego `flash`,
  y dentro de cada grupo el de versión más reciente.
- **FR-006**: La preferencia MUST ser opcional: la ausencia de configuración MUST NOT impedir arrancar
  ni analizar fotos.
- **FR-007**: El listado de modelos MUST conservarse 24 horas, para no consultarlo en cada
  análisis, y MUST refrescarse al caducar o cuando un modelo resulte no encontrado.
- **FR-008**: El listado MUST mantenerse separado por clave de IA y MUST NOT compartirse entre
  personas. Se guarda solo en memoria del proceso, indexado por huella (hash) de la clave; nunca se
  escribe en disco ni con la clave en claro, y se pierde al reiniciar. Los modelos evitados por
  saturación (FR-009) siguen el mismo almacenamiento.
- **FR-009**: Un modelo que responda con saturación (503) MUST evitarse durante 3 minutos antes de
  volver a intentarlo.
- **FR-010**: Guardar o comprobar la clave MUST NOT depender de que ningún modelo de análisis esté
  operativo.
- **FR-011**: Cada análisis MUST registrar el modelo usado, si fue la preferencia o una sustitución y,
  si hubo fallos intermedios, el código de respuesta y la categoría de cada uno.
- **FR-012**: El registro MUST NOT contener la clave, la foto, la respuesta de la IA, mensajes del
  proveedor ni descripciones introducidas por la persona.
- **FR-013**: La respuesta de cualquier modelo MUST validarse con el mismo esquema que hoy; el cambio
  de modelo MUST NOT relajar la confirmación del usuario ni el cruce con la base de alimentos.
- **FR-014**: Cuando no exista ningún modelo compatible para la clave, el sistema MUST devolver un
  aviso específico y la persona MUST poder continuar a mano.
- **FR-015**: Los avisos que ve la persona MUST seguir siendo los de la 006 (clave inválida, límite
  alcanzado, proveedor no disponible, tiempo agotado); esta feature MUST NOT añadir pantallas ni
  ajustes para elegir modelo.
- **FR-016**: Las pruebas MUST funcionar sin llamar al proveedor real, con un proveedor simulado que
  permita listar, retirar y saturar modelos.

### Key Entities

- **Modelo disponible**: un modelo que el proveedor ofrece a la clave de la persona; tiene un nombre y
  las capacidades que declara (generar texto, admitir imágenes).
- **Preferencia de modelos**: lista ordenada y opcional que fija el operador; indica por qué modelos
  empezar. No es un dato de la persona.
- **Listado en caché**: modelos disponibles de una clave concreta con su momento de obtención; caduca y
  no persiste.
- **Resultado de elección**: modelo usado en un análisis, si fue preferencia o sustitución y los
  intentos fallidos previos; solo existe en el registro.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Con el modelo preferido retirado, el 100 % de los análisis de foto se completan con otro
  modelo, sin cambios de código ni de configuración.
- **SC-002**: Con el primer candidato saturado, el análisis termina dentro del mismo tiempo máximo que
  hoy en el 95 % de los casos en que otro candidato está disponible.
- **SC-003**: Guardar una clave válida se acepta en el 100 % de los casos aunque todos los modelos de
  análisis estén saturados.
- **SC-004**: En un día normal, el listado de modelos se consulta como máximo una vez por clave y
  periodo de caducidad, y no una vez por análisis.
- **SC-005**: Para cualquier fallo con el proveedor, Erick identifica la categoría (modelo no
  encontrado, saturación, red, tiempo agotado, clave) en menos de un minuto mirando el registro.
- **SC-006**: Ninguna entrada de registro generada por la feature contiene clave, foto, respuesta de
  la IA ni texto del proveedor.
- **SC-007**: Pasados al menos seis meses sin tocar configuración, el análisis de fotos sigue
  funcionando mientras exista algún modelo compatible para la clave.

## Assumptions

- Solo hay un proveedor de IA (Gemini); soportar varios proveedores queda fuera de alcance.
- El proveedor no indica qué modelos tienen capa gratuita; por eso la preferencia la mantiene Erick
  y el criterio de respaldo se basa en preferir modelos rápidos y económicos.
- Las personas no eligen modelo: es una decisión del servidor, y no se añade ninguna pantalla.
- La clave de IA sigue siendo por persona (006) y puede dar acceso a modelos distintos según el
  proyecto de origen.
- La comprobación de la clave ya usa el listado de modelos (corrección previa a esta spec) y esta
  feature la da por existente.
- Se mantiene el tiempo máximo de espera del análisis de la 006; reintentar con otro modelo ocurre
  dentro de ese margen.
- Cualquier valor de preferencia ya configurado en el entorno sigue funcionando como primer elemento
  de la lista de preferencia.
- Fuera de alcance: medir costes, mostrar a la persona qué modelo se usó y comparar calidad entre
  modelos.
