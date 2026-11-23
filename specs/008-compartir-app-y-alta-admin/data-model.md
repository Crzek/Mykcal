# Data Model: Compartir la app y alta del administrador sin código

Esta feature no añade tablas, columnas ni migraciones.

## Enlace de descarga (valor derivado, no persistido)

| Campo | Origen | Regla |
|---|---|---|
| `downloadLink` | `API_BASE_URL` del sabor + `/descargar/mykcal.apk` | Empieza por `https://`; sin barra doble entre base y ruta |

- Prod: `https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk`
- Dev: `https://mykcal-bk-dev-api.cruzerick.com/descargar/mykcal.apk`

## Texto compartido

`«Prueba Mykcal, la app para registrar lo que comes: <downloadLink>»`. Es un texto fijo de
`app_es.arb`. No lleva nombre, código ni identificador (FR-006).

## Alta (cambio de comportamiento, mismo modelo)

Las tablas `user_account`, `invitation_code`, `registration_throttle` y `registration_failure` de la
001 no cambian. Solo cambia cuándo se escribe en ellas:

| Entrada | Administrador | No administrador |
|---|---|---|
| Código vacío tras normalizar | Crea `user_account` (como en la 001) | `400 INVITATION_REQUIRED`; **no** escribe en `registration_failure` |
| Código no vacío | Crea `user_account` (ignora el código) | Igual que en la 001 |
