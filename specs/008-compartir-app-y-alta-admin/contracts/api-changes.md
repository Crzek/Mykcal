# Cambios de API

El contrato vivo sigue siendo `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, porque las
pruebas de contrato lo leen. Esta feature lo modifica así:

## `POST /v1/registration`

- `invitation_code` acepta la cadena vacía para todos. El schema ya lo permitía; solo cambia la
  descripción.
- Respuesta `400`: además de `INVITATION_INVALID`, puede devolver `INVITATION_REQUIRED`.

```yaml
"400":
  description: >
    INVITATION_INVALID (código erróneo, sustituido o inexistente) o
    INVITATION_REQUIRED (código vacío de un usuario que no es administrador; no cuenta como intento)
```

- `components.schemas.ErrorBody.code`: se añade `INVITATION_REQUIRED` al `enum`.

### Orden de evaluación para un no administrador

1. Ya registrado → `409 ALREADY_REGISTERED` (sin cambios)
2. **Código vacío tras normalizar → `400 INVITATION_REQUIRED`** (nuevo; antes del bloqueo; no suma fallo)
3. Bloqueo activo → `429 TOO_MANY_ATTEMPTS` (sin cambios)
4. Código erróneo → `400 INVITATION_INVALID` y suma fallo (sin cambios)
5. Sin plazas → `409 NO_SEATS` (sin cambios)

## Rutas públicas

Sin cambios: `/v1/health` y `/descargar/mykcal.apk`.
