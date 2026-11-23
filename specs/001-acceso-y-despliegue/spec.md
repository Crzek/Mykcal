# Feature Specification: Acceso por invitación y sesión

**Feature Branch**: `001-acceso-y-despliegue`

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "001-acceso-y-despliegue: Acceso por invitación y sesión (épica E1, P1) + esqueleto desplegado. El usuario recibe de Erick un código de invitación y se registra; sin código válido el registro no se completa. Inicio de sesión con el proveedor de identidad de Erick. Todas las funciones exigen sesión válida. Consulta de la identidad y del estado de la cuenta; una cuenta desactivada no puede operar. Rol administrador: gestionar el código de invitación. La feature termina con una app instalable que inicia sesión contra el servidor desplegado."

## Clarifications

### Session 2026-11-22

- Q: ¿Cómo se gestiona el código de invitación? → A: Hay un único código activo; el administrador puede cambiarlo y el anterior deja de valer para altas nuevas. Las cuentas ya creadas no se ven afectadas.
- Q: ¿Se bloquean las altas al llegar a 50 cuentas? → A: Sí, al llegar a 50 cuentas activas el registro se rechaza aunque el código sea válido. Las desactivadas no cuentan.
- Q: ¿Puede el administrador ver los datos de otros usuarios? → A: No. El administrador solo gestiona el código de invitación.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrarse con código de invitación (Priority: P1)

Una persona del círculo de Erick recibe el código de invitación, instala la app desde el enlace,
crea su cuenta introduciendo el código y queda con la sesión iniciada.

**Why this priority**: sin alta no hay usuarios; es la puerta de entrada al resto de la app y el
mecanismo que limita el acceso al círculo cercano.

**Independent Test**: instalar la app, registrarse con el código vigente y comprobar que se llega a
la pantalla de inicio con la identidad del usuario visible; repetir con un código erróneo y
comprobar que el alta no se completa.

**Acceptance Scenarios**:

1. **Given** una persona sin cuenta y el código vigente, **When** completa el registro con ese
   código, **Then** se crea su cuenta activa y entra en la app con la sesión iniciada.
2. **Given** una persona sin cuenta, **When** introduce un código incorrecto o uno ya sustituido,
   **Then** el registro no se completa, se muestra un mensaje claro y no se crea ninguna cuenta.
3. **Given** que ya hay 50 cuentas activas, **When** alguien intenta registrarse con el código
   vigente, **Then** el registro se rechaza con un mensaje que indica que no hay plazas.

---

### User Story 2 - Iniciar y cerrar sesión (Priority: P1)

Un usuario registrado abre la app, inicia sesión con sus credenciales y accede a su espacio. Puede
cerrar sesión cuando quiera. La sesión se mantiene entre aperturas de la app mientras sea válida.

**Why this priority**: todas las funciones exigen identidad válida; sin sesión no hay uso.

**Independent Test**: con una cuenta existente, iniciar sesión, cerrar la app, reabrirla (sigue
dentro), cerrar sesión (vuelve a la pantalla de acceso).

**Acceptance Scenarios**:

1. **Given** un usuario con cuenta activa, **When** inicia sesión con credenciales correctas,
   **Then** entra en la app y ve su identidad.
2. **Given** un usuario con sesión iniciada, **When** cierra la app y la vuelve a abrir,
   **Then** sigue dentro sin volver a introducir credenciales mientras la sesión sea válida.
3. **Given** un usuario con sesión iniciada, **When** cierra sesión, **Then** vuelve a la pantalla
   de acceso y ninguna función queda disponible hasta iniciar sesión de nuevo.
4. **Given** un usuario cuya cuenta está desactivada, **When** intenta iniciar sesión o usar la
   app, **Then** se le deniega el acceso con un mensaje que indica que la cuenta está desactivada.

---

### User Story 3 - Toda función exige identidad (Priority: P1)

Cualquier petición al servidor sin una identidad válida, caducada o de una cuenta desactivada se
rechaza. El servidor puede responder quién es el usuario autenticado y el estado de su cuenta.

**Why this priority**: es la base de la seguridad y del aislamiento por usuario de toda la app.

**Independent Test**: llamar al servidor sin identidad, con identidad caducada, con identidad de una
cuenta desactivada y con identidad válida; solo la última obtiene respuesta con sus datos.

**Acceptance Scenarios**:

1. **Given** una petición sin identidad o con identidad inválida o caducada, **When** llega al
   servidor, **Then** se rechaza sin devolver datos.
2. **Given** un usuario con identidad válida y cuenta activa, **When** consulta su identidad,
   **Then** recibe su identificador, su nombre visible, si es administrador y el estado "activa".
3. **Given** un usuario con identidad válida y cuenta desactivada, **When** hace cualquier
   petición distinta de consultar su identidad, **Then** se rechaza.

---

### User Story 4 - Gestionar el código de invitación (Priority: P2)

El administrador (Erick) consulta el código vigente y lo sustituye por uno nuevo cuando sospecha
que se ha compartido fuera del círculo. También ve cuántas plazas quedan.

**Why this priority**: mitiga el riesgo de que el código se filtre; puede hacerse a mano al
principio, por eso no es P1.

**Independent Test**: como administrador, cambiar el código; comprobar que el antiguo ya no permite
registrarse y el nuevo sí; comprobar que un usuario normal no puede ver ni cambiar el código.

**Acceptance Scenarios**:

1. **Given** el administrador con sesión iniciada, **When** consulta la gestión de invitaciones,
   **Then** ve el código vigente y el número de cuentas activas sobre 50.
2. **Given** el administrador, **When** sustituye el código por uno nuevo, **Then** el código
   anterior deja de valer para altas nuevas y las cuentas existentes no se ven afectadas.
3. **Given** un usuario que no es administrador, **When** intenta ver o cambiar el código,
   **Then** se le deniega y no ve la opción en la app.

---

### User Story 5 - App instalable conectada al servidor desplegado (Priority: P1)

Erick comparte un enlace a la app instalable; el usuario la instala en su Android y la app se
comunica con el servidor desplegado en la infraestructura de Erick.

**Why this priority**: la constitución exige que cada feature termine usable en el móvil y
desplegada; esta feature crea el esqueleto sobre el que se apoyan las demás.

**Independent Test**: descargar la app desde el enlace en un móvil Android, instalarla e iniciar
sesión contra el servidor desplegado.

**Acceptance Scenarios**:

1. **Given** un móvil Android, **When** el usuario abre el enlace e instala la app, **Then** la app
   arranca y muestra la pantalla de acceso.
2. **Given** el servidor desplegado, **When** la app inicia sesión, **Then** obtiene la identidad
   del usuario desde ese servidor.

---

### Edge Cases

- **Sin conexión**: la app avisa de que necesita conexión; lo que el usuario estaba escribiendo
  (por ejemplo, el código de invitación) no se pierde y puede reintentar.
- **Código con espacios o en otro caso de letras**: se ignoran espacios al principio y al final y
  la comparación no distingue mayúsculas de minúsculas.
- **Intentos repetidos con códigos erróneos**: tras 3 fallos seguidos de la misma identidad se
  aplica una espera creciente (30 s duplicándose, máximo 1 h). Si los fallos entre todas las
  identidades llegan a 20 en 10 minutos, se bloquean todas las altas 10 minutos.
- **Sesión caducada mientras se usa la app**: la app intenta renovarla de forma transparente; si
  no puede, lleva al usuario a iniciar sesión sin perder lo que estaba escribiendo en pantalla.
- **El código cambia mientras alguien está registrándose**: si el código introducido ya no es el
  vigente en el momento de confirmar, el alta no se completa.
- **Dos personas ocupan la plaza 50 a la vez**: solo una alta se completa; la otra recibe el
  mensaje de que no hay plazas.
- **El servidor no responde**: la app muestra un error claro y permite reintentar.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir crear una cuenta de Mykcal solo a quien introduzca el código
  de invitación vigente. Única excepción: la cuenta del administrador (ver Assumptions), que puede
  crearse sin código para poder generar el primero.
- **FR-002**: El sistema MUST rechazar el registro cuando haya 50 cuentas activas, aunque el código
  sea válido. Las cuentas desactivadas no cuentan para el límite.
- **FR-003**: El sistema MUST mantener un único código de invitación vigente a la vez.
- **FR-004**: El administrador MUST poder consultar el código vigente y sustituirlo por uno nuevo;
  al sustituirlo, el anterior deja de valer de inmediato para altas nuevas.
- **FR-005**: El administrador MUST poder ver el número de cuentas activas y las plazas libres.
- **FR-006**: El sistema MUST NOT permitir al administrador ver datos de salud ni registros de
  otros usuarios.
- **FR-007**: Los usuarios MUST poder iniciar sesión mediante el proveedor de identidad de Erick y
  cerrar sesión desde la app.
- **FR-008**: La app MUST mantener la sesión entre aperturas mientras sea válida y renovarla de
  forma transparente cuando sea posible.
- **FR-009**: El sistema MUST rechazar toda petición sin identidad válida, sin devolver datos.
- **FR-010**: El sistema MUST identificar a cada usuario por el identificador estable que emite el
  proveedor de identidad.
- **FR-011**: El sistema MUST ofrecer una consulta de la identidad del usuario autenticado que
  devuelva su identificador, nombre visible, si es administrador y el estado de la cuenta
  (activa o desactivada).
- **FR-012**: El sistema MUST rechazar cualquier otra operación de una cuenta desactivada.
- **FR-013**: El sistema MUST limitar los intentos de registro fallidos repetidos con una espera
  creciente por identidad y, además, con un límite global que bloquee temporalmente todas las altas
  si los fallos entre todas las identidades superan un umbral (evita adivinar el código creando
  identidades nuevas).
- **FR-014**: El sistema MUST registrar el 100% de los errores del servidor, sin incluir tokens ni
  credenciales en los registros.
- **FR-015**: Sin conexión, la app MUST avisar al usuario y conservar lo que estaba escribiendo en
  pantalla.
- **FR-016**: Todos los textos de la app MUST estar en español y externalizados para poder
  traducirse.
- **FR-017**: La app MUST cumplir WCAG 2.1 AA en contraste, respetar el tamaño de texto del sistema,
  etiquetar todos los controles para el lector de pantalla y seguir el tema claro u oscuro del
  sistema.
- **FR-018**: La app MUST distribuirse como instalable de Android mediante un enlace, y el servidor
  MUST quedar desplegado en la infraestructura de Erick.
- **FR-019**: MUST existir dos entornos separados, con datos y cuentas de Mykcal independientes: producción
  (publicado desde la rama `main`) y desarrollo (publicado desde la rama `dev`). Cada entorno tiene
  su propia app instalable, apuntando a su servidor.

### Key Entities

- **Usuario**: persona registrada. Atributos: identificador del proveedor de identidad, nombre
  visible, si es administrador, estado (activa → desactivada), fecha de alta.
- **Código de invitación**: código vigente que permite registrarse. Atributos: valor, fecha de
  creación, quién lo creó. Solo uno vigente a la vez; los anteriores quedan como históricos.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Una persona con el código puede instalar la app, registrarse y entrar en menos de
  5 minutos.
- **SC-002**: El 100% de los intentos de registro con un código no vigente se rechazan sin crear
  cuenta.
- **SC-003**: El 100% de las peticiones sin identidad válida o de cuentas desactivadas se rechazan
  (verificado con pruebas automáticas sobre todas las funciones).
- **SC-004**: Tras cambiar el código, el 100% de los intentos con el código anterior se rechazan.
- **SC-005**: Ningún intento de alta supera las 50 cuentas activas.
- **SC-006**: Un usuario con sesión iniciada reabre la app y entra sin volver a introducir
  credenciales en el 100% de los casos con sesión válida.
- **SC-007**: El 100% de las pantallas de esta feature pasan la revisión de contraste AA y tienen
  etiquetas para el lector de pantalla.

## Assumptions

- Se reutiliza el proveedor de identidad autoalojado de Erick (ya en uso en otras apps) con un
  proyecto nuevo para Mykcal, y el patrón de inicio de sesión de Ligón.
- El administrador es una cuenta concreta (la de Erick) marcada como tal en la configuración del
  despliegue; no hay pantalla para nombrar otros administradores. Puede registrarse sin código
  (al principio no existe ninguno) y ocupa una de las 50 plazas.
- El proveedor de identidad (Zitadel) permite crear usuarios sin código; el código controla el
  alta de la cuenta de Mykcal. Sin cuenta de Mykcal no se puede usar ninguna función. Los usuarios
  del proveedor se comparten entre producción y desarrollo; las cuentas y los datos no.
- La desactivación de cuentas la implementa la feature 002 (baja); aquí solo se respeta el estado.
- El registro de datos de salud no ocurre en esta feature; el consentimiento llega en la 002.
- Nombre visible y email salen del proveedor de identidad; Mykcal no gestiona contraseñas.
- La app requiere conexión; no hay modo sin conexión.
- No hay objetivo de tiempo de respuesta ni de disponibilidad (decisión de Erick).
- El aviso de caída del servidor a Erick (pregunta abierta 12) queda fuera de esta feature.
