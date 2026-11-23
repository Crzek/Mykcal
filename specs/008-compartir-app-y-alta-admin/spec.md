# Feature Specification: Compartir la app y alta del administrador sin código

**Feature Branch**: `008-compartir-app-y-alta-admin`

**Created**: 2026-11-23

**Status**: Draft

**Input**: User description: "Mejoras de la 001 detectadas en la prueba real en móvil. (1) Compartir la app: desde la app el usuario con sesión iniciada puede ver el enlace público de descarga del APK, copiarlo y compartirlo mediante el menú de compartir del móvil. (2) Alta del administrador sin código: la primera vez, el administrador debe poder crear su cuenta sin escribir un código inventado; el campo es opcional para él y sigue siendo obligatorio para el resto."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compartir el enlace de descarga desde la app (Priority: P1)

Una persona con la cuenta activa quiere que alguien de su círculo pruebe Mykcal. Abre la app, ve
el enlace de descarga, lo copia o lo envía con el menú de compartir del móvil (mensajería, correo…)
sin tener que pedírselo a Erick ni buscarlo por su cuenta.

**Why this priority**: hoy el enlace solo lo conoce quien lo recibió fuera de la app. Es lo que
Erick pidió tras publicar el primer APK y habilita que el círculo crezca. El enlace solo lleva a
la descarga; para registrarse sigue haciendo falta el código de invitación.

**Independent Test**: con la sesión iniciada, abrir la opción de compartir, comprobar que se ve el
enlace, copiarlo y pegarlo en otra app, y abrir el menú de compartir del móvil con el enlace ya
rellenado.

**Acceptance Scenarios**:

1. **Given** un usuario con la cuenta activa, **When** abre la opción de compartir la app, **Then**
   ve el enlace de descarga completo y las acciones «Copiar» y «Compartir».
2. **Given** el enlace visible, **When** pulsa «Copiar», **Then** el enlace queda en el portapapeles
   y la app lo confirma con un aviso breve.
3. **Given** el enlace visible, **When** pulsa «Compartir», **Then** se abre el menú de compartir del
   móvil con un texto en español que incluye el enlace.
4. **Given** el entorno de producción, **When** se muestra el enlace, **Then** apunta a la descarga
   del APK de producción; en otro entorno apunta a la de ese entorno.
5. **Given** que alguien abre el enlace en un navegador, **When** el APK está publicado, **Then**
   lo descarga sin iniciar sesión (comportamiento ya existente, no cambia).

---

### User Story 2 - Alta del administrador sin inventar un código (Priority: P2)

Erick, como administrador, instala la app por primera vez e inicia sesión en Zitadel. La app le
pide el código de invitación, pero él todavía no tiene ninguno (lo genera después, desde la propia
app). Debe poder continuar sin escribir nada y entrar con su cuenta de administrador.

**Why this priority**: es un tropiezo del primer arranque, no un bloqueo: hoy funciona escribiendo
cualquier texto, pero resulta confuso y se descubrió en la prueba real. Se hace una sola vez.

**Independent Test**: con una cuenta de Zitadel que sea la del administrador y sin cuenta en
Mykcal, dejar el campo del código vacío, continuar y comprobar que se entra con el menú
«Invitaciones».

**Acceptance Scenarios**:

1. **Given** el administrador sin cuenta en Mykcal, **When** deja el código vacío y continúa,
   **Then** se crea su cuenta y entra con el menú «Invitaciones».
2. **Given** el administrador sin cuenta, **When** escribe cualquier texto como código y continúa,
   **Then** el resultado es el mismo y el texto se ignora (comportamiento actual).
3. **Given** un usuario que no es administrador, **When** deja el código vacío y continúa, **Then**
   no se crea la cuenta y la app le pide el código con un mensaje claro.
4. **Given** un usuario que no es administrador, **When** escribe un código válido o inválido,
   **Then** se comporta exactamente como en la 001 (alta, mensaje de código no válido, límite de
   intentos y de plazas).

---

### Edge Cases

- Sin conexión al abrir la opción de compartir: el enlace se muestra igual, porque no depende de
  la red; compartir y copiar siguen funcionando.
- Un usuario con la cuenta desactivada no llega a la opción de compartir (no entra en la app).
- El usuario cancela el menú de compartir del móvil: no hay error ni cambio de estado.
- El portapapeles no está disponible: la app avisa de que no se pudo copiar y deja el enlace visible.
- El APK aún no está publicado y alguien abre el enlace: el servidor responde que no existe; la
  app no lo comprueba antes de mostrar el enlace.
- Un usuario sin cuenta (pantalla del código) no ve la opción de compartir.
- Código vacío de un no administrador: no cuenta como intento fallido a efectos del límite de
  intentos, porque no se ha comprobado ningún código.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Un usuario con la cuenta activa MUST poder ver, desde la app, el enlace público de
  descarga del APK de su entorno.
- **FR-002**: La app MUST ofrecer copiar el enlace al portapapeles y confirmarlo al usuario.
- **FR-003**: La app MUST ofrecer compartir el enlace con el menú de compartir del sistema, con un
  texto breve en español que lo acompañe.
- **FR-004**: El enlace MUST salir de la configuración del entorno de la app, no escrito a mano en
  cada pantalla, y cambiar con el entorno (producción o desarrollo).
- **FR-005**: Mostrar, copiar y compartir el enlace MUST funcionar sin conexión y sin llamadas
  adicionales al servidor.
- **FR-006**: Compartir el enlace MUST NOT incluir el código de invitación, el identificador de la
  cuenta ni ningún dato personal; el texto compartido solo lleva el enlace y la invitación a
  descargarlo.
- **FR-007**: En la pantalla del código de invitación, el botón de continuar MUST estar disponible
  con el campo vacío.
- **FR-008**: Si la cuenta de Zitadel es la del administrador y no tiene cuenta en Mykcal, el alta
  MUST completarse con el código vacío, igual que hoy con cualquier texto.
- **FR-009**: Si el usuario no es administrador y envía el código vacío, el sistema MUST rechazar
  el alta con un mensaje en español que pida el código, sin crear cuenta.
- **FR-010**: El código vacío de un no administrador MUST NOT contar para el límite de intentos
  fallidos (FR-013 de la 001).
- **FR-011**: Para los no administradores, todo lo demás del alta MUST permanecer igual: código
  vigente, mensaje de código no válido, límite de intentos y límite de 50 cuentas activas.
- **FR-012**: Todos los textos nuevos MUST estar en español, y los registros del servidor MUST NOT
  incluir el código escrito, el enlace compartido ni el identificador de Zitadel en claro.
- **FR-013**: Los escenarios existentes de `quickstart.md` de la 001 MUST seguir cumpliéndose.

### Key Entities *(include if feature involves data)*

- **Enlace de descarga**: dirección pública del APK de un entorno. No se guarda ni se consulta; se
  deriva de la configuración del entorno de la app.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario con la cuenta activa puede enviar el enlace de descarga a otra persona en
  menos de 15 segundos desde la pantalla de inicio, sin ayuda.
- **SC-002**: El 100 % de las veces, el enlace mostrado coincide con el de descarga del entorno en
  el que está instalada la app.
- **SC-003**: El administrador completa su alta inicial sin escribir ningún texto en el campo del
  código, en menos de 1 minuto desde que vuelve de Zitadel.
- **SC-004**: En las pruebas, el 100 % de los no administradores con código vacío no obtienen
  cuenta, y ninguno de ellos se ve penalizado en el límite de intentos.
- **SC-005**: Los 12 escenarios del `quickstart.md` de la 001 siguen pasando sin cambios.

## Assumptions

- La opción de compartir está al alcance de cualquier usuario con la cuenta activa, no solo del
  administrador; el administrador sigue siendo el único que genera códigos.
- La pantalla de inicio es el sitio natural de la opción (un acceso visible), sin crear una sección
  nueva; el diseño exacto se decide en el plan.
- La app no sabe si el usuario es administrador antes de crear su cuenta, así que el botón queda
  disponible con el campo vacío para todos y es el servidor quien decide (FR-008 y FR-009).
- El texto que acompaña al enlace es fijo y en español; no se personaliza con el nombre del usuario.
- Publicar el APK en el servidor (`publish_apk.sh`) queda fuera de esta feature: es una operación
  del administrador ya cubierta por la 001.
- Esta feature no cambia la constitución: no se añaden rutas públicas, y la descarga sigue siendo
  la única ruta pública de distribución.
