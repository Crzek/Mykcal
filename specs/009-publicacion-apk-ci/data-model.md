# Modelo de datos: Publicación automática del APK

No hay tablas ni cambios de base de datos. Las «entidades» de la spec se concretan en configuración y
archivos.

## Publicación (una ejecución del workflow)

| Campo | Origen |
|---|---|
| Origen | `push` (merge) o `workflow_dispatch` (manual) |
| Entorno | `prod` o `dev` |
| Commit | SHA compilado (`github.sha` o el `ref` manual validado) |
| Número de versión | `build-number` = minutos UTC desde época en el momento de compilar |
| Resultado | éxito, fallo (con paso) u omitida (dev sin configurar) |

**Estados**: `iniciada → compilada → firma verificada → subida → publicada → verificada → ok`;
cualquier fallo → `fallida` y, si ya se había publicado, `restaurada` (vuelve la copia `.prev`).
Dev sin configurar: `iniciada → omitida`.

## APK publicado

Un archivo por entorno: `${PUBLISH_DIR}/mykcal.apk`. Archivos transitorios durante la publicación:
`mykcal.apk.tmp` (subida) y `mykcal.apk.prev` (copia de retorno); ninguno persiste tras terminar.

## Configuración de publicación (por entorno de GitHub)

| Nombre | Tipo | Contenido | Obligatoria |
|---|---|---|---|
| `KEYSTORE_BASE64` | secreto | keystore en base64 | sí |
| `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` | secreto | datos de firma | sí |
| `SSH_PRIVATE_KEY` | secreto | clave dedicada, solo escritura en la carpeta del APK | sí |
| `SSH_KNOWN_HOSTS` | secreto | línea(s) `known_hosts` del servidor | sí |
| `PUBLISH_HOST` | secreto | `usuario@servidor` | sí |
| `PUBLISH_DIR` | secreto | ruta del volumen del APK | sí |
| `SIGNING_CERT_SHA256` | variable | huella esperada del certificado | sí |
| `APK_BASE_URL` | variable | `https://mykcal-bk-api.cruzerick.com` (prod) | sí |

Un entorno está «configurado» si existen todas; si falta alguna, `development` se omite (FR-011) y
`production` falla nombrando la que falta (sin valores).
