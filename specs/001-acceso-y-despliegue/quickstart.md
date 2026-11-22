# Quickstart: validar la 001

Guía para comprobar la feature de principio a fin. Los detalles están en
[contracts/](./contracts/) y [data-model.md](./data-model.md).

## Requisitos

- Python 3.12 y `uv`; Docker (para PostgreSQL local y testcontainers).
- Flutter ≥ 3.32 y un emulador Android (API ≥ 24).
- Zitadel configurado según [contracts/zitadel-setup.md](./contracts/zitadel-setup.md).
- `app/config/dev.json` y `app/config/prod.json` con `OIDC_ISSUER`, `OIDC_ORG_ID`,
  `OIDC_PROJECT_ID`, `OIDC_CLIENT_ID` y `API_BASE_URL`. No son secretos.

## 1. Backend en local

```bash
cd backend
docker compose -f docker-compose.dev.yml up -d   # PostgreSQL local
cp .env.example .env                              # rellenar OIDC_* y ADMIN_SUBJECT
uv sync
uv run pytest                                     # todo verde
uv run pytest -m privacy                          # SC-003: rutas sin identidad o desactivadas → rechazo
uv run uvicorn mykcal.main:create_app --factory --reload
curl -s localhost:8000/v1/health                  # {"status":"ok"}
curl -si localhost:8000/v1/me | head -1           # 401
```

## 2. App en el emulador (sabor dev contra el backend de dev)

```bash
cd app
flutter test                                      # incluye las guías de accesibilidad (SC-007)
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

## 3. Escenarios end-to-end (emulador, entorno dev desplegado)

| # | Pasos | Resultado esperado |
|---|---|---|
| 1 | Erick (`ADMIN_SUBJECT`) inicia sesión sin código | Entra; InicioScreen con el menú «Invitaciones» |
| 2 | Invitaciones → «Cambiar código» | Aparece el código; «1 de 50 cuentas activas» |
| 3 | Otro usuario: «Crear cuenta» en Zitadel → código erróneo | «El código no es válido»; `GET /v1/me` sigue en 404 (US1-2) |
| 4 | Mismo usuario: código vigente escrito en minúsculas y con espacios | Cuenta creada y entra (US1-1, caso límite) |
| 5 | Cerrar la app y reabrirla | Sigue dentro sin credenciales (US2-2, SC-006) |
| 6 | Erick cambia el código; un tercero prueba con el anterior | Rechazado (US4-2, SC-004) |
| 7 | Cinco códigos erróneos seguidos | Desde el 4.º, cuenta atrás y `429` (FR-013) |
| 8 | Usuario normal | No ve «Invitaciones»; `GET /v1/admin/invitation` → 403 (US4-3) |
| 9 | Modo avión mientras escribe el código → Continuar | Banner sin conexión; el texto se conserva (FR-015) |
| 10 | Cerrar sesión | AccesoScreen; la app borra los tokens y no puede renovar; el access token viejo caduca solo en ≤ 15 min (US2-3, riesgo aceptado en research R4) |
| 11 | Poner `status='disabled'` a mano en la base de dev para un usuario | Pantalla «Cuenta desactivada»; `/v1/admin/*` → 403 (US2-4, US3-3) |
| 12 | Texto del sistema al 200 % y tema oscuro | Todo legible y sin cortes (FR-017) |

Plazas (US1-3, SC-005) y concurrencia: las cubren pruebas automáticas, porque no son prácticas
a mano con 50 cuentas.

## 4. Despliegue y APK (US5)

1. Merge de la feature a `dev`: Dokploy despliega `mykcal-bk-dev-api.cruzerick.com`.
2. `app/scripts/build_apk.sh dev && app/scripts/publish_apk.sh dev`.
3. En un móvil Android: abrir `https://mykcal-bk-dev-api.cruzerick.com/descargar/mykcal.apk`,
   instalar e iniciar sesión.
4. Merge de `dev` a `main`, y lo mismo con `prod` y `mykcal-bk-api.cruzerick.com`.
5. Con el móvil limpio: instalar, registrarse y entrar en menos de 5 min (SC-001).
