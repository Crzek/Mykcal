# Research: Compartir la app y alta del administrador sin código

No quedaban `NEEDS CLARIFICATION` en el contexto técnico. Estas son las decisiones de diseño.

## R1. Hoja de compartir del sistema: `share_plus`

**Decisión**: usar `share_plus` ^12.0.2, la última versión compatible con las restricciones
actuales del proyecto (13.x pide subir otras dependencias). Se envuelve en un puerto propio
(`SharePort`) para poder sustituirlo en las pruebas.

**Razón**: es el paquete oficial de la comunidad Flutter (*Flutter Favorite*) y en Android lanza
`Intent.ACTION_SEND` con el selector del sistema. No pide permisos ni toca el manifest.

**Alternativas**:
- Canal de plataforma propio con `ACTION_SEND`: unas 30 líneas de Kotlin más su prueba. Es más
  código que mantener para el mismo resultado (principio VII).
- Solo copiar al portapapeles: no cumple FR-003.

## R2. Origen del enlace: derivado de `API_BASE_URL`

**Decisión**: `downloadLink = '$API_BASE_URL/descargar/mykcal.apk'`, calculado en una sola función
de `core/config/` a partir del `--dart-define` que ya fija cada sabor (`config/prod.json`,
`config/dev.json`).

**Razón**: el backend ya sirve el APK en esa ruta y cada sabor apunta a su backend. Así el enlace
cambia con el entorno (FR-004), funciona sin red (FR-005) y no añade ninguna ruta (principio V).

**Alternativas**:
- Nueva clave `DOWNLOAD_URL` en `config/*.json`: duplica un dato que ya se puede derivar y podría
  desincronizarse del backend.
- Que `GET /v1/me` devuelva el enlace: necesita red, toca el contrato y no aporta nada.

## R3. Código vacío de un no administrador: `400 INVITATION_REQUIRED` sin contar intento

**Decisión**: en `accounts/service.register`, si `normalize(raw_code) == ""` y el usuario no es
administrador, se responde `400 INVITATION_REQUIRED` («Escribe el código de invitación.») **antes**
de consultar el bloqueo y sin llamar a `register_failure`. El administrador sigue igual (ignora el
código). Los códigos no vacíos siguen el camino de la 001 sin cambios.

**Razón**:
- FR-010: un código vacío no compara nada y no debe penalizar.
- Un código propio permite a la app mostrar «Escribe el código» en lugar de «El código no es
  válido» sin adivinar a partir del texto del campo.
- Responder antes del bloqueo no filtra información: no revela nada del código vigente.

**Alternativas**:
- Validar el vacío solo en la app: la app no sabe si el usuario es administrador antes de crear la
  cuenta (`GET /v1/me` devuelve 403 `ACCOUNT_NOT_REGISTERED` sin `is_admin`).
- Reutilizar `INVITATION_INVALID` sin contar el intento: el mensaje no pediría el código (FR-009).
- Exponer `is_admin` en el 403 de `/v1/me`: amplía el contrato de error para un caso de un solo uso.

## R4. Dónde vive la opción de compartir

**Decisión**: entrada «Compartir Mykcal» en el menú (⋮) de la pantalla de inicio, visible para todos
los usuarios activos. Abre una hoja inferior modal (`showModalBottomSheet`) con el enlace en texto
seleccionable, «Copiar» y «Compartir».

**Razón**: el menú ya existe y agrupa «Invitaciones» y «Cerrar sesión». La hoja no cambia de
pantalla, se cierra con el gesto atrás y se reutiliza si más adelante hay más pantallas.

**Alternativas**:
- Botón fijo en el cuerpo de inicio: ese espacio será de las features 002–007.
- Pantalla nueva: más navegación para dos botones.

## R5. Confirmación al copiar

**Decisión**: `Clipboard.setData` y después un `SnackBar` «Enlace copiado». Si lanza
`PlatformException`, sale el `SnackBar` «No se pudo copiar el enlace» y el enlace sigue visible.

**Razón**: cumple FR-002 y el caso límite del portapapeles. El `SnackBar` se anuncia en el lector de
pantalla.
