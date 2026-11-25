# Contrato del workflow `publish-apk.yml`

## Disparadores

| Evento | Condición | Entorno |
|---|---|---|
| `push` a `main` | cambia algo en `app/**` | `prod` |
| `push` a `dev` | cambia algo en `app/**` | `dev` (omitido si no está configurado) |
| `workflow_dispatch` | entradas abajo | el elegido |
| `pull_request`, otras ramas | — | **nunca publica** |

### Entradas manuales

| Entrada | Tipo | Defecto | Regla |
|---|---|---|---|
| `environment` | `prod` \| `dev` | `prod` | obligatoria |
| `ref` | texto (commit) | punta de `main` (o `dev`) | debe ser ancestro de la rama del entorno; si no, falla antes de compilar |

## Concurrencia

`group: publish-apk-<entorno>`, `cancel-in-progress: false`.

## Pasos (orden y comportamiento ante fallo)

1. Comprobar configuración del entorno (secretos y variables). Falta algo → prod/manual: fallo con
   los **nombres** que faltan; `push` a `dev`: salida en verde con aviso.
2. Validar `ref` (solo manual).
3. Preparar firma y SSH (archivos en `$RUNNER_TEMP`, permisos 600).
4. `app/scripts/build_apk.sh <flavor>` (versión por hora, compila, comprueba huella).
5. `app/scripts/publish_apk.sh <flavor>` (sube, atómico, verifica, restaura si falla).
6. Limpieza de firma y claves (`if: always()`).

Cualquier fallo marca la ejecución como fallida; GitHub envía el correo por defecto (FR-004).

## Permisos y registros

`permissions: contents: read`. Ningún paso imprime secretos; no hay `set -x`; los artefactos de la
ejecución no incluyen el keystore ni `key.properties`.
