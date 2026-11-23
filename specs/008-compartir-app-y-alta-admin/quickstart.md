# Quickstart: validación de la 008

## 1. Pruebas automáticas

```bash
cd backend && uv run ruff check && uv run pytest          # incluye contrato y privacidad
cd app && flutter analyze && flutter test
```

Todo en verde.

## 2. APK en el móvil

```bash
app/scripts/build_apk.sh prod
adb install -r app/build/app/outputs/flutter-apk/app-prod-release.apk
```

## 3. Escenarios

| # | Pasos | Resultado esperado | Requisito |
|---|---|---|---|
| 1 | Usuario activo → ⋮ → «Compartir Mykcal» | Hoja con el enlace de prod completo | FR-001, FR-004 |
| 2 | «Copiar» y pegar en otra app | Se pega el enlace exacto; aviso «Enlace copiado» | FR-002 |
| 3 | «Compartir» → elegir una app de mensajería | Texto en español con el enlace, sin datos personales | FR-003, FR-006 |
| 4 | Modo avión → repetir 1–3 | Todo funciona; el envío real lo hará la app de destino | FR-005 |
| 5 | Usuario que no es admin | Ve «Compartir Mykcal» y no ve «Invitaciones» | Assumptions |
| 6 | Admin sin cuenta (base vacía o cuenta nueva con `ADMIN_SUBJECT`) → código vacío → Continuar | Entra con «Invitaciones» | FR-007, FR-008, SC-003 |
| 7 | No admin → código vacío → Continuar | «Escribe el código de invitación.»; sin cuenta | FR-009 |
| 8 | No admin → 5 veces código vacío, luego un código erróneo | El erróneo da «no es válido», no `429`: los vacíos no contaron | FR-010, SC-004 |
| 9 | Escenarios 3, 4 y 7 de `specs/001-acceso-y-despliegue/quickstart.md` | Mismo resultado que en la 001 | FR-011, FR-013 |

## 4. Publicación

Con el APK publicado (`publish_apk.sh prod`), abrir en el navegador el enlace de la hoja debe
descargar `mykcal.apk` con `200`.
