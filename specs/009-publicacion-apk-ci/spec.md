# Feature Specification: Publicación automática del APK

**Feature Branch**: `009-publicacion-apk-ci`

**Created**: 2026-11-23

**Status**: Draft

**Input**: User description: "Publicación automática del APK con GitHub Actions. Al fusionar en main (producción) se compila el APK de prod firmado y se publica en el volumen del servidor de Dokploy para que https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk sirva la versión nueva; opcionalmente lo mismo para dev con su entorno. El keystore, sus contraseñas y la clave SSH viven como secretos de GitHub, nunca en el repositorio. La publicación es atómica, se verifica que la descarga responde 200 tras publicar, y si falla la compilación o la subida el APK anterior sigue disponible. Debe poder lanzarse también a mano. Sustituye al flujo manual build_apk.sh + publish_apk.sh, que se mantiene como alternativa."

## Clarifications

### Session 2026-11-25

- Q: ¿Cómo se calcula el número de versión del APK para que crezca entre publicaciones automáticas y manuales? → A: Se deriva de la fecha y hora de compilación (UTC, en minutos); el mismo cálculo vale para el proceso automático y el flujo manual.
- Q: ¿Cómo se entera Erick de que falló una publicación automática? → A: Con el aviso por correo que GitHub envía por defecto al fallar la ejecución, además del historial; sin avisos propios ni secretos extra.
- Q: ¿Cómo se detecta que la clave de firma no coincide con la de los APK ya distribuidos? → A: Se compara la huella SHA-256 del certificado del APK compilado con una huella esperada guardada como variable del repositorio (no secreta); si no coincide, falla antes de subir.
- Q: Al lanzar la publicación a mano para producción, ¿desde qué versión del código se compila? → A: Por defecto la última de `main`; se puede indicar un commit anterior, pero solo si pertenece a `main`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Publicar producción al fusionar en `main` (Priority: P1)

Erick fusiona `dev` en `main`. Sin hacer nada más, en unos minutos el enlace público de descarga
sirve el APK nuevo, firmado con la clave de siempre, y los usuarios pueden instalarlo encima del
que ya tienen.

**Why this priority**: hoy publicar exige compilar en el portátil de Erick y subir a mano por SSH.
Es el paso que se olvida o se hace mal, y la constitución dice que `main` es lo que tienen los
usuarios: el APK debe seguir a `main` sin intervención.

**Independent Test**: fusionar un cambio visible de la app en `main`, esperar a que termine la
publicación, descargar el APK del enlace público, instalarlo sobre la versión anterior y ver el
cambio.

**Acceptance Scenarios**:

1. **Given** un merge en `main` que cambia la app, **When** termina la publicación, **Then** el
   enlace de descarga de producción sirve el APK nuevo y responde correctamente.
2. **Given** un APK anterior instalado en un móvil, **When** se instala el nuevo, **Then** se
   actualiza encima sin desinstalar y conserva la sesión.
3. **Given** dos publicaciones seguidas, **When** se comparan, **Then** la segunda tiene un número
   de versión mayor que la primera.
4. **Given** un merge en `main` que no toca la app (solo backend o documentación), **When** se
   procesa, **Then** no se publica un APK nuevo.

---

### User Story 2 - Un fallo no rompe la descarga (Priority: P1)

Si la compilación o la subida fallan, quien abra el enlace sigue descargando el último APK
correcto, nunca uno a medias ni un error. Erick ve que falló y por qué.

**Why this priority**: el enlace se comparte con el círculo (feature 008); un enlace roto deja
fuera a quien intenta instalar.

**Independent Test**: forzar un fallo de compilación y otro de subida; en ambos casos el enlace
sigue sirviendo el APK anterior y la ejecución aparece como fallida con la causa.

**Acceptance Scenarios**:

1. **Given** una compilación que falla, **When** termina el proceso, **Then** no se sube nada y el
   enlace sirve el APK anterior.
2. **Given** una subida que se corta a mitad, **When** alguien descarga, **Then** obtiene el APK
   anterior completo.
3. **Given** que tras publicar la descarga no responde correctamente, **When** termina el proceso,
   **Then** se marca como fallido y Erick lo ve en el historial de ejecuciones del repositorio.

---

### User Story 3 - Lanzar la publicación a mano (Priority: P2)

Erick quiere republicar sin fusionar nada (por ejemplo, tras recrear el volumen del servidor o
para probar el proceso). Lo lanza a mano desde el repositorio eligiendo el entorno.

**Why this priority**: recuperación ante incidentes y prueba del proceso; no es el camino diario.

**Independent Test**: lanzar a mano la publicación de producción y comprobar que el enlace sirve
el APK compilado desde la última versión de `main`.

**Acceptance Scenarios**:

1. **Given** el repositorio, **When** Erick lanza la publicación a mano para producción, **Then**
   se compila desde `main` y se publica igual que en el flujo automático.
2. **Given** que el entorno de desarrollo aún no existe, **When** se lanza para desarrollo,
   **Then** el proceso termina con un mensaje claro de que falta su configuración, sin tocar
   producción.

---

### User Story 4 - Entorno de desarrollo (Priority: P3)

Cuando exista el entorno de desarrollo, un merge en `dev` publica el APK de desarrollo en su
propio enlace, separado del de producción.

**Why this priority**: el entorno de desarrollo está aplazado (T072 de la 001); esto queda
preparado para cuando exista.

**Independent Test**: con el entorno de desarrollo configurado, fusionar en `dev` y comprobar que
solo cambia el enlace de desarrollo.

**Acceptance Scenarios**:

1. **Given** el entorno de desarrollo configurado, **When** se fusiona en `dev`, **Then** se
   publica el APK de desarrollo en su enlace y el de producción no cambia.
2. **Given** el entorno de desarrollo sin configurar, **When** se fusiona en `dev`, **Then** no se
   intenta publicar y no aparece como fallo.

---

### Edge Cases

- Dos merges seguidos en `main`: la segunda publicación espera o sustituye a la primera; nunca se
  intercalan y el enlace acaba sirviendo la más reciente.
- Falta algún secreto (clave de firma, contraseña, acceso al servidor): el proceso falla al inicio
  con un mensaje que dice qué falta, sin mostrar el valor de ninguno.
- La clave de firma no coincide con la de los APK ya publicados: el proceso no publica, porque los
  usuarios no podrían actualizar encima.
- El servidor no responde o rechaza el acceso: falla la subida y el APK anterior sigue sirviéndose.
- El volumen del servidor está vacío (recién creado): la primera publicación lo deja servido.
- El proceso manual (`build_apk.sh` + `publish_apk.sh`) y el automático publican en el mismo sitio:
  gana el último en terminar, sin dejar archivos a medias.
- Una rama de feature o un pull request no publica nunca.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cada merge en `main` que cambie la app MUST compilar el APK de producción firmado y
  publicarlo en el enlace público de descarga de producción, sin intervención manual.
- **FR-002**: Los merges en `main` que no cambien la app MUST NOT publicar un APK nuevo.
- **FR-003**: La publicación MUST ser atómica: en ningún momento el enlace sirve un APK incompleto
  o inexistente si antes había uno correcto.
- **FR-004**: Si falla cualquier paso (compilación, firma, subida o comprobación), el enlace MUST
  seguir sirviendo el APK anterior y la ejecución MUST quedar marcada como fallida con su causa, de modo que GitHub avise a Erick por
  correo con su notificación por defecto (sin aviso propio ni secretos adicionales).
- **FR-005**: Tras publicar, el proceso MUST comprobar que el enlace público responde
  correctamente y sirve el archivo recién subido (mismo tamaño o huella).
- **FR-006**: Cada APK publicado MUST tener un número de versión estrictamente mayor que el
  anterior, para que el móvil lo trate como actualización. El número se deriva de la fecha y hora
  de compilación (UTC, en minutos) con el mismo cálculo en el proceso automático y en el flujo
  manual, de modo que crece aunque se alternen ambos.
- **FR-007**: El APK MUST firmarse con la misma clave que los ya distribuidos; si la firma no
  coincide, MUST NOT publicarse. La comprobación compara la huella SHA-256 del certificado del APK
  compilado con una huella esperada guardada como variable del repositorio y falla antes de subir.
- **FR-008**: La clave de firma, sus contraseñas y el acceso al servidor MUST guardarse como
  secretos del repositorio y MUST NOT aparecer en el repositorio, en los registros de ejecución ni
  en los artefactos.
- **FR-009**: Erick MUST poder lanzar la publicación a mano eligiendo el entorno (producción o
  desarrollo). Por defecto se compila la última versión de `main`; MAY indicar un commit anterior,
  solo si pertenece a `main` (así se vuelve a una versión previa); nunca una rama sin fusionar.
- **FR-010**: Dos publicaciones del mismo entorno MUST NOT ejecutarse a la vez.
- **FR-011**: La publicación de desarrollo MUST usar su propio enlace y configuración y MUST NOT
  afectar a producción; si su configuración no existe, MUST omitirse sin marcar fallo en los
  merges automáticos.
- **FR-012**: Las ramas de feature y los pull requests MUST NOT publicar.
- **FR-013**: El flujo manual existente (`build_apk.sh` + `publish_apk.sh`) MUST seguir funcionando
  como alternativa y publicar en el mismo sitio con la misma garantía de atomicidad.
- **FR-014**: La documentación de despliegue MUST explicar qué secretos hay que dar de alta, cómo
  lanzar la publicación a mano y cómo volver a una versión anterior.

### Key Entities *(include if feature involves data)*

- **Publicación**: una ejecución del proceso para un entorno. Tiene origen (merge o manual),
  versión del código, número de versión del APK, resultado y causa del fallo si la hay.
- **APK publicado**: el archivo que sirve el enlace de un entorno. Hay como mucho uno vigente por
  entorno.
- **Secretos de publicación**: clave de firma y sus contraseñas, y credenciales de acceso al
  servidor, por entorno cuando difieran.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Tras un merge en `main` que cambia la app, el APK nuevo está descargable en menos de
  15 minutos sin ninguna acción manual.
- **SC-002**: En el 100 % de las publicaciones fallidas forzadas en las pruebas, el enlace sigue
  sirviendo el APK anterior completo.
- **SC-003**: El 100 % de los APK publicados se instalan como actualización sobre el anterior sin
  desinstalar.
- **SC-004**: Ningún registro de ejecución ni archivo del repositorio contiene la clave de firma,
  sus contraseñas ni credenciales del servidor (revisión de los registros de 3 ejecuciones).
- **SC-005**: Erick pasa de unos 5 pasos manuales por publicación a ninguno en el caso normal.

## Assumptions

- El repositorio está en GitHub y se usan sus ejecuciones automáticas; su plan gratuito basta
  para el volumen de publicaciones previsto (pocas a la semana).
- El servidor de Dokploy acepta acceso por SSH con una clave dedicada a esta tarea, con permiso
  de escritura solo en la carpeta del volumen del APK.
- El APK se sigue sirviendo desde el backend (`/descargar/mykcal.apk`); no se cambia a otro
  alojamiento (por ejemplo, GitHub Releases), porque el enlace ya se comparte y debe ser estable.
- «Cambia la app» significa que el merge modifica archivos de `app/`.
- El número de versión se deriva de la hora de compilación (ver Clarifications); el número visible (1.0.0) se sigue cambiando a mano cuando Erick quiera.
- Volver a una versión anterior se hace relanzando la publicación sobre un commit anterior de
  `main` o con el flujo manual; no se guarda un historial de APK en el servidor.
- El entorno de desarrollo sigue aplazado; esta feature lo deja preparado pero no lo crea.
