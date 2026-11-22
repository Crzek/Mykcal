# Feature Specification: Base de alimentos, código de barras y alimentos personalizados

**Feature Branch**: `003-base-de-alimentos`

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "003-base-de-alimentos: importación de la base genérica, búsqueda, código de barras con caché y alimentos personalizados. Épicas E4 y E8."

## Clarifications

### Session 2026-11-22

- Q: ¿Qué se muestra cuando un alimento no tiene datos de algún micro? → A: el dato que falta
  cuenta como 0 en los totales y el total se marca como "incompleto" con un aviso que lo explica.
- Q: ¿Qué micros se guardan? → A: sodio, potasio, calcio, hierro, magnesio, vitamina D y
  vitamina C, además de la fibra (ver 002).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Buscar un alimento genérico (Priority: P1)

El usuario escribe el nombre de un alimento fresco o básico ("plátano", "arroz cocido",
"pechuga de pollo") y obtiene una lista de coincidencias de la base de alimentos genérica, con sus
valores por 100 g.

**Why this priority**: es la forma de registro que siempre funciona, sin IA ni código de barras, y
la fuente de valores nutricionales fiables para el resto de features.

**Independent Test**: buscar alimentos habituales y comprobar que aparecen con kcal, macros, fibra
y micros por 100 g.

**Acceptance Scenarios**:

1. **Given** la base genérica cargada, **When** el usuario busca "platano", **Then** aparece
   "Plátano" entre los primeros resultados aunque no haya escrito la tilde.
2. **Given** un resultado, **When** lo abre, **Then** ve kcal, proteína, carbohidratos, grasa,
   fibra y los 7 micros por 100 g, con los que no tienen dato marcados como "sin dato".
3. **Given** una búsqueda sin coincidencias, **When** termina, **Then** se le ofrece crear un
   alimento personalizado con ese nombre.

---

### User Story 2 - Escanear un código de barras (Priority: P1)

El usuario escanea el código de barras de un producto envasado y obtiene el producto con sus
valores nutricionales por 100 g y, si existe, el tamaño de la ración del envase.

**Why this priority**: los envasados son una parte grande de lo que se come y escanear es el
registro más rápido y preciso.

**Independent Test**: escanear productos conocidos (encontrado, no encontrado, ya consultado) y
comprobar el resultado en cada caso.

**Acceptance Scenarios**:

1. **Given** un producto que existe en la base pública de productos envasados, **When** el usuario
   escanea su código, **Then** ve nombre, marca, valores por 100 g (o 100 ml) y la ración del
   envase si existe.
2. **Given** un código ya consultado antes por cualquier usuario, **When** se vuelve a escanear,
   **Then** el producto se obtiene de la copia local sin volver a consultar la base pública.
3. **Given** un código que no existe en la base pública, **When** se escanea, **Then** se ofrece
   crear un alimento personalizado con ese código asociado.
4. **Given** un producto encontrado sin kcal ni macros, **When** se muestra, **Then** se trata como
   no utilizable y se ofrece crear un alimento personalizado con ese código.
5. **Given** el usuario sin permiso de cámara, **When** abre el escáner, **Then** se le explica por
   qué se necesita y se le ofrece introducir el código a mano.

---

### User Story 3 - Crear y gestionar alimentos personalizados (Priority: P2)

El usuario crea un alimento propio (un plato casero o un producto sin código) con su nombre y sus
valores por 100 g o por ración, y lo encuentra después en sus búsquedas. Solo él lo ve.

**Why this priority**: cubre lo que no está en las bases, pero la base genérica y el código de
barras ya cubren la mayoría de casos.

**Independent Test**: crear un alimento personalizado, buscarlo, editarlo y comprobar que otro
usuario no lo ve.

**Acceptance Scenarios**:

1. **Given** el formulario de alimento personalizado, **When** el usuario introduce nombre, kcal,
   proteína, carbohidratos y grasa por 100 g, **Then** el alimento se guarda; fibra y micros son
   opcionales.
2. **Given** que el usuario indica los valores por ración, **When** introduce el tamaño de la
   ración en gramos, **Then** el sistema guarda también los valores equivalentes por 100 g.
3. **Given** un alimento personalizado, **When** el usuario busca por su nombre, **Then** aparece
   en los resultados, identificado como suyo.
4. **Given** otro usuario, **When** busca ese mismo nombre o escanea su código, **Then** no ve el
   alimento personalizado del primero.
5. **Given** un alimento personalizado, **When** el usuario lo edita o lo elimina, **Then** los
   cambios se aplican a usos futuros; las comidas ya registradas mantienen los valores con los que
   se guardaron.
6. **Given** un alimento personalizado con código de barras, **When** el mismo usuario escanea ese
   código, **Then** obtiene su alimento personalizado antes que el resultado de la base pública.

---

### Edge Cases

- **Valores incoherentes** en un alimento personalizado (por ejemplo, macros que suman más de
  100 g por 100 g, o valores negativos): se rechazan con un mensaje junto al campo.
- **Kcal que no cuadran con los macros** (más de un 15% de diferencia): se avisa sin impedir
  guardar.
- **Base pública de envasados caída o lenta**: se avisa de que no se ha podido consultar y se
  ofrece reintentar o crear un alimento personalizado.
- **Producto envasado con datos en ml**: los valores se tratan por 100 ml y la cantidad se indica
  en ml.
- **Producto cuyos datos públicos cambian**: la copia local se renueva cuando tiene más de 30 días.
- **Búsqueda muy corta** (menos de 2 caracteres): no se lanza.
- **Muchos resultados**: se muestran los 20 más relevantes; primero los personalizados del usuario,
  después los genéricos y después los envasados ya consultados.

## Requirements *(mandatory)*

### Functional Requirements

**Base genérica**

- **FR-001**: El sistema MUST incluir una base de alimentos genéricos con nombres en español y
  valores por 100 g de kcal, proteína, carbohidratos, grasa, fibra y los 7 micros clave.
- **FR-002**: La carga de la base genérica MUST poder repetirse sin duplicar alimentos.
- **FR-003**: Un nutriente sin dato MUST distinguirse de un nutriente con valor 0.

**Búsqueda**

- **FR-004**: Los usuarios MUST poder buscar alimentos por nombre, sin distinguir mayúsculas ni
  tildes, con resultados a partir de 2 caracteres.
- **FR-005**: La búsqueda MUST devolver los alimentos personalizados del propio usuario, los
  genéricos y los envasados ya conocidos, ordenados por relevancia con los personalizados primero,
  limitados a 20 resultados.

**Código de barras**

- **FR-006**: Los usuarios MUST poder escanear un código de barras con la cámara o introducirlo a
  mano.
- **FR-007**: El sistema MUST buscar el código primero entre los alimentos personalizados del
  usuario, después en la copia local y, si no está, en la base pública de productos envasados.
- **FR-008**: El sistema MUST guardar una copia local de cada producto consultado en la base
  pública, compartida por todos los usuarios, y renovarla cuando tenga más de 30 días.
- **FR-009**: Si el producto no existe o no tiene kcal y macros, el sistema MUST ofrecer crear un
  alimento personalizado con el código asociado.
- **FR-010**: Si el producto tiene tamaño de ración, el sistema MUST ofrecerlo para indicar la
  cantidad en raciones.

**Alimentos personalizados**

- **FR-011**: Los usuarios MUST poder crear, editar y eliminar alimentos personalizados con nombre,
  kcal, proteína, carbohidratos y grasa obligatorios; fibra, micros, marca, código de barras y
  tamaño de ración opcionales.
- **FR-012**: Los alimentos personalizados MUST ser visibles solo para el usuario que los creó.
- **FR-013**: Los valores introducidos por ración MUST convertirse y guardarse también por 100 g.
- **FR-014**: El sistema MUST validar que no hay valores negativos y que los macros no superan
  100 g por 100 g, y avisar si las kcal difieren más de un 15% de las calculadas con los macros.
- **FR-015**: Editar o eliminar un alimento personalizado MUST NOT cambiar las entradas ya
  registradas en el diario.

**Datos incompletos**

- **FR-016**: Cuando a un alimento le falte un micro o la fibra, el sistema MUST mostrarlo como
  "sin dato"; en los totales cuenta como 0 y el total se marca como "incompleto".

**Transversales**

- **FR-017**: Todas las pantallas MUST estar en español, usar unidades métricas y cumplir
  WCAG 2.1 AA.
- **FR-018**: Las pruebas MUST NOT consultar la base pública real: usan respuestas guardadas.

### Key Entities

- **Alimento**: algo que se puede registrar. Tipo: genérico (de la base), envasado (por código de
  barras) o personalizado (de un usuario). Atributos: nombre, marca opcional, código de barras
  opcional, unidad base (g o ml), valores por 100 g/ml de kcal, macros, fibra y micros (cada uno
  con valor o "sin dato"), tamaño de ración opcional, origen y fecha de actualización.
- **Alimento personalizado**: alimento cuyo dueño es un usuario; solo él lo ve.
- **Copia local de envasado**: producto obtenido de la base pública, compartido entre usuarios,
  con fecha de consulta.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Al menos el 90% de una lista de 50 alimentos frescos habituales (definida en el plan)
  aparece entre los 5 primeros resultados al buscar su nombre.
- **SC-002**: El usuario obtiene el producto tras escanear un código ya consultado en menos de
  2 segundos.
- **SC-003**: El 100% de los códigos no encontrados ofrecen crear un alimento personalizado.
- **SC-004**: 0 alimentos personalizados visibles para usuarios distintos de su creador
  (verificado con pruebas automáticas).
- **SC-005**: Un usuario crea un alimento personalizado en menos de 1 minuto.

## Assumptions

- La base genérica es BEDCA (alimentos españoles), siempre que su licencia permita este uso; Erick
  la verifica antes del plan (pregunta abierta 6). Si no lo permite, se usa otra base pública con
  nombres en español y los mismos nutrientes, sin cambiar esta spec.
- La base pública de productos envasados es Open Food Facts.
- No se modifica la base genérica desde la app; solo se recarga desde una fuente nueva.
- Los alimentos personalizados no se comparten entre usuarios (fuera de alcance en el MVP).
- El registro en el diario de un alimento encontrado es de la feature 004; aquí la feature termina
  en encontrar, ver y crear alimentos.
