# Contrato de los scripts (`app/scripts/`)

## `build_apk.sh <prod|dev>`

Variables opcionales: `MYKCAL_BUILD_NUMBER` (fuerza el número; por defecto minutos UTC desde época),
`MYKCAL_EXPECTED_CERT_SHA256` (huella esperada; en CI viene de `SIGNING_CERT_SHA256`).

| Código | Significado |
|---|---|
| 0 | APK compilado, firmado y huella coincidente (o sin huella esperada: aviso en local) |
| 1 | falta `key.properties`, `config/<flavor>.json` con valores vacíos o huella distinta |
| 2 | uso incorrecto |

Salida: `build/app/outputs/flutter-apk/app-<flavor>-release.apk` y la línea `VERSION_CODE=<n>`.

## `apk_cert_sha256.sh <apk>`

Imprime la huella SHA-256 del certificado de firma (hex en minúsculas, sin `:`). Sale 1 si el APK no
está firmado o `apksigner` no está disponible.

## `publish_apk.sh <prod|dev>`

Entorno: `PUBLISH_HOST`, `PUBLISH_DIR_PROD` o `PUBLISH_DIR_DEV` (si no existe
`~/.config/mykcal/publish.env`, que sigue funcionando); `APK_BASE_URL` opcional (por defecto la URL
del entorno).

| Código | Significado |
|---|---|
| 0 | publicado y verificado por huella; `.prev` borrado |
| 1 | falta APK/variable, subida fallida (APK anterior intacto) o verificación fallida (restaurado) |
| 2 | uso incorrecto |

Garantías: nunca se escribe `mykcal.apk` salvo con `mv` atómico; ante error de verificación se
restaura la copia anterior; ningún mensaje contiene valores de secretos.
