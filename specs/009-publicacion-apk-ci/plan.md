# Implementation Plan: Publicación automática del APK

**Branch**: `009-publicacion-apk-ci` | **Date**: 2026-11-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-publicacion-apk-ci/spec.md`

## Summary

Un workflow de GitHub Actions (`.github/workflows/publish-apk.yml`) compila el APK firmado y lo
publica en el volumen del servidor de Dokploy cuando se fusiona en `main` algo que toca `app/`
(producción) o en `dev` (desarrollo, omitido si no está configurado), y también a mano con
`workflow_dispatch`. La lógica no vive en el YAML: el workflow llama a los mismos scripts que el
flujo manual (`app/scripts/build_apk.sh` y `publish_apk.sh`), que se amplían con el número de versión
por hora de compilación, la comprobación de la huella de firma, la subida atómica con copia de
retorno y la verificación por huella de la descarga pública. Así el flujo manual y el automático
publican igual (FR-013) y la lógica se prueba sin GitHub ni servidor (principio VI). Decisiones en
[research.md](./research.md).

## Technical Context

**Language/Version**: Bash (scripts), YAML de GitHub Actions; Flutter estable fijado a la versión
local (se anota en el workflow), JDK 17, Android SDK `build-tools` (`apksigner`) del runner.

**Primary Dependencies**: `actions/checkout`, `actions/setup-java`, `subosito/flutter-action`,
`openssh-client` y `curl` del runner `ubuntu-latest`. Sin código de backend ni de app nuevo.

**Storage**: archivos en el volumen del servidor (`/data/apk/mykcal.apk`); sin base de datos.

**Testing**: pruebas de shell con `ssh`/`scp`/`curl`/`apksigner` simulados en el `PATH`
(`app/scripts/tests/`), `shellcheck` y `actionlint`; validación real con una publicación de prueba.

**Target Platform**: runner Linux de GitHub; destino: servidor Dokploy por SSH.

**Project Type**: infraestructura de entrega (CI/CD) sobre el monorepo app + backend.

**Performance Goals**: publicación completa < 15 min tras el merge (SC-001).

**Constraints**: ningún secreto en repositorio, registros ni artefactos (FR-008); el enlace
`/descargar/mykcal.apk` no cambia; APK anterior servido ante cualquier fallo (FR-004).

**Scale/Scope**: pocas publicaciones a la semana, 2 entornos (prod; dev preparado), un solo
mantenedor.

## Constitution Check

*GATE: debe pasar antes de la fase 0. Reevaluado tras la fase 1.*

| Principio | Resultado |
|---|---|
| I–III (IA propone, base de alimentos, IA opcional) | No aplica: no toca IA ni nutrición. |
| IV Privacidad y datos de salud | Cumple: no se tocan datos de usuarios; el CI no recibe datos de salud. |
| V Aislamiento y seguridad | Cumple: clave SSH dedicada con permiso solo sobre la carpeta del APK, `known_hosts` fijado, secretos por entorno de GitHub. |
| VI Cálculos y pruebas sin servicios reales | Cumple: lógica en scripts probados con comandos simulados. |
| VII Simplicidad | Cumple: se reutilizan los scripts existentes; sin servicios ni herramientas nuevas. |
| VIII Accesible, español, métrico | No aplica: sin interfaz; mensajes de los scripts en español. |
| IX Entrega vertical y desplegada | Cumple: se cierra con una publicación real instalada como actualización en el móvil. |
| X Observabilidad sin contenido sensible | Cumple: los registros no contienen claves; los secretos se enmascaran y los archivos temporales de firma se borran. |
| Flujo `feature → dev → main` | Cumple: solo `main` y `dev` publican; ramas de feature y PR nunca. |

Sin violaciones: no se rellena la tabla de complejidad. Reevaluado tras el diseño: sigue sin haberlas.

## Project Structure

### Documentation (this feature)

```text
specs/009-publicacion-apk-ci/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── workflow.md          # disparadores, entradas, secretos, variables, salidas
│   └── scripts.md           # CLI y códigos de salida de los scripts
└── tasks.md                 # lo genera /speckit-tasks
```

### Source Code (repository root)

```text
.github/workflows/
└── publish-apk.yml                  # NUEVO: disparadores, concurrencia, pasos

app/scripts/
├── build_apk.sh                     # MODIFICA: número de versión por hora, huella de firma
├── publish_apk.sh                   # MODIFICA: env opcional, copia de retorno, verificación, rollback
├── apk_cert_sha256.sh               # NUEVO: extrae la huella SHA-256 del certificado de un APK
└── tests/
    ├── stubs/                       # ssh, scp, curl, apksigner simulados
    └── test_scripts.sh              # casos de FR-003/004/005/006/007

docs/deploy/
└── publicar-apk.md                  # NUEVO: secretos, lanzamiento manual, rollback (FR-014)
docs/deploy/produccion.md            # MODIFICA: el paso 4 apunta al flujo automático
```

**Structure Decision**: infraestructura sin código de producto. Todo vive en `.github/` y
`app/scripts/`; el backend y la app no cambian (el APK se sigue sirviendo desde
`distribution/router.py`).

## Complexity Tracking

Sin violaciones que justificar.
