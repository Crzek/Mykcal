# Implementation Plan: Compartir la app y alta del administrador sin código

**Branch**: `008-compartir-app-y-alta-admin` | **Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-compartir-app-y-alta-admin/spec.md`

## Summary

Son dos mejoras pequeñas sobre la 001.

1. **Compartir la app.** Se añade la entrada «Compartir Mykcal» al menú de la pantalla de inicio.
   Abre una hoja inferior con el enlace de descarga y dos acciones: «Copiar» y «Compartir». El
   enlace se calcula en la app como `API_BASE_URL + /descargar/mykcal.apk`, así que no hace falta
   red ni ruta nueva. Copiar usa el portapapeles del sistema y compartir usa `share_plus`.
2. **Alta del administrador sin código.** En la app, el botón «Continuar» deja de exigir texto. En
   el backend, un código vacío tras normalizar se trata aparte: el administrador sigue entrando como
   hasta ahora, y un no administrador recibe `400 INVITATION_REQUIRED` sin registrar un intento
   fallido.

## Technical Context

**Language/Version**: Python 3.12 (backend); Dart ≥ 3.5 / Flutter ≥ 3.32 (app). Sin cambios respecto a la 001.

**Primary Dependencies**:
- Backend: las de la 001, sin añadidos.
- App: las de la 001, más `share_plus` ^12.0.2 para la hoja de compartir del sistema (R1).

**Storage**: sin cambios. No hay tablas ni columnas nuevas ni migraciones.

**Testing**:
- Backend: pytest con integración sobre testcontainers y contrato contra
  `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, que se amplía con el código
  `INVITATION_REQUIRED`.
- App: flutter_test + mocktail. La hoja de compartir se prueba sustituyendo el puerto de
  compartir; el portapapeles, con el canal simulado de `SystemChannels.platform`.

**Target Platform**: Android API ≥ 24; contenedor Linux en Dokploy.

**Project Type**: móvil + API (monorepo `backend/` + `app/`).

**Performance Goals**: ninguno formal. SC-001 pide compartir en menos de 15 s.

**Constraints**:
- Mostrar, copiar y compartir funcionan sin conexión (FR-005).
- Ninguna ruta pública nueva (principio V).
- Textos en `app_es.arb`, accesibles para el lector de pantalla (principio VIII).
- Sin el código escrito ni el `sub` en los registros (principio X, FR-012).

**Scale/Scope**: 1 hoja nueva en la app, 1 pantalla modificada, 1 código de error y 1 rama nueva en
el servicio de alta.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| I. La IA propone | N/A | Sin IA. |
| II. Base de alimentos | N/A | Sin datos nutricionales. |
| III. IA opcional | N/A | — |
| IV. Privacidad y salud | ✅ | No se guarda nada. El texto compartido solo lleva el enlace (FR-006). |
| V. Aislamiento y seguridad | ✅ | La descarga ya era pública y no se añade ninguna ruta, así que la prueba de rutas públicas no cambia. El alta sigue exigiendo JWT. |
| VI. Pruebas sin servicios reales | ✅ | Zitadel simulado en el backend; puerto de compartir sustituido en la app. |
| VII. Simplicidad | ✅ | Sin infraestructura. El enlace se deriva de la configuración existente en vez de una ruta o un ajuste de servidor (R2). Solo se añade una dependencia, `share_plus`, justificada en R1. |
| VIII. Accesible y en español | ✅ | Textos nuevos en `app_es.arb`. Botones con etiqueta y el enlace legible y seleccionable. |
| IX. Entrega vertical | ✅ | Se cierra con APK de prod instalado en el móvil y los escenarios de `quickstart.md`. |
| X. Observabilidad | ✅ | No se añaden registros: el `400` es un error de cliente, como `INVITATION_INVALID` en la 001. La prueba de logs sin secretos sigue cubriendo el alta. |
| Ramas y entornos | ⚠️ Justificado | La rama sale de `001-acceso-y-despliegue` y no de `dev`, porque necesita el arreglo de `taskAffinity` del PR #3, aún sin fusionar. Su PR a `dev` se abre cuando el PR #3 esté fusionado; el historial queda igual que si saliera de `dev`. |

**Resultado**: pasa. La excepción de ramas está en *Complexity Tracking*.

**Re-check tras el diseño (Phase 1)**: sin cambios. El contrato solo añade un código de error a una
ruta ya autenticada.

## Project Structure

### Documentation (this feature)

```text
specs/008-compartir-app-y-alta-admin/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── api-changes.md   # cambio en POST /v1/registration
│   └── ui-flows.md      # hoja «Compartir Mykcal» y pantalla del código
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── src/mykcal/
│   ├── core/errors.py              # + ErrorCode.INVITATION_REQUIRED
│   └── accounts/service.py         # código vacío de no admin → 400 sin contar intento
└── tests/
    ├── integration/test_registration.py          # código vacío: admin 201, no admin 400
    └── integration/test_registration_throttle.py # código vacío no suma fallos

specs/001-acceso-y-despliegue/contracts/openapi.yaml   # 400 documenta INVITATION_REQUIRED

app/
├── pubspec.yaml                          # + share_plus
├── lib/
│   ├── core/config/download_link.dart    # enlace derivado de API_BASE_URL
│   ├── core/share/share_port.dart        # puerto de compartir (share_plus en prod)
│   ├── features/share/share_app_sheet.dart
│   ├── features/home/home_screen.dart    # + entrada de menú «Compartir Mykcal»
│   ├── features/registration/code_screen.dart            # Continuar sin texto
│   ├── features/registration/registration_controller.dart # INVITATION_REQUIRED
│   └── l10n/app_es.arb                   # textos nuevos
└── test/
    ├── share/share_app_sheet_test.dart
    ├── home/home_screen_test.dart        # la entrada aparece para todos
    └── registration/code_screen_test.dart # vacío habilitado y mensaje nuevo
```

**Structure Decision**: se mantiene el monorepo de la 001. La hoja de compartir va en su propia
carpeta `features/share/` porque no pertenece ni a inicio ni a administración.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Rama creada desde `001-acceso-y-despliegue`, no desde `dev` | Sin el arreglo de `taskAffinity`, el login del APK no funciona y no se puede probar la feature en el móvil (principio IX) | Partir de `dev` obligaría a repetir el arreglo en dos ramas o a esperar al PR #3 para empezar |
