# Tasks: Compartir la app y alta del administrador sin código

**Input**: Design documents from `specs/008-compartir-app-y-alta-admin/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: se incluyen. Se sigue la práctica de la 001 (test primero) y el principio VI.

**Organization**: por historia de usuario. US1 (compartir) y US2 (admin sin código) son
independientes: no comparten archivos salvo `app_es.arb`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de `spec.md` (US1, US2)

---

## Phase 1: Setup

- [X] T001 Añadir `share_plus: ^12.0.2` a `dependencies` en `app/pubspec.yaml` (R1) y ejecutar `flutter pub get` en `app/`

---

## Phase 2: Foundational

No hay tareas bloqueantes comunes. Cada historia empieza directamente tras el Setup (US2 ni siquiera necesita T001).

---

## Phase 3: User Story 1 - Compartir el enlace de descarga (Priority: P1) 🎯 MVP

**Goal**: un usuario activo abre «Compartir Mykcal» desde el menú de inicio, ve el enlace de su entorno, lo copia o lo comparte, sin red.

**Independent Test**: escenarios 1–5 de `quickstart.md`.

### Tests for User Story 1 ⚠️ (escribir primero y comprobar que fallan)

- [X] T002 [P] [US1] Test unitario de `downloadLink` en `app/test/config/download_link_test.dart`: con base `https://mykcal-bk-api.cruzerick.com` da `https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk`; con barra final en la base no produce `//descargar`; una base sin `https://` lanza `StateError` (data-model: «Empieza por `https://`; sin barra doble entre base y ruta»)
- [X] T003 [P] [US1] Widget test de la hoja en `app/test/share/share_app_sheet_test.dart`, con un `SharePort` falso de mocktail y el canal `SystemChannels.platform` simulado:
  - muestra el título «Compartir Mykcal», la explicación y el enlace en un `SelectableText`;
  - «Copiar» escribe el enlace exacto en el portapapeles y muestra el `SnackBar` «Enlace copiado»;
  - si el canal lanza `PlatformException`, muestra «No se pudo copiar el enlace» y la hoja sigue abierta;
  - «Compartir» llama a `SharePort.share` con el texto de `shareText` que contiene el enlace y no contiene el nombre del usuario (FR-006);
  - ningún `Dio` ni API se invoca (FR-005);
  - los botones miden al menos 48 dp de alto y tienen etiqueta semántica (`meetsGuideline(androidTapTargetGuideline)` y `labeledTapTargetGuideline`)
- [X] T004 [P] [US1] Ampliar `app/test/home/home_menu_test.dart`: el menú ⋮ muestra «Compartir Mykcal» tanto para un usuario normal como para el administrador; al pulsarlo se abre la hoja; «Invitaciones» sigue apareciendo solo al administrador

### Implementation for User Story 1

- [X] T005 [P] [US1] Crear `app/lib/core/config/download_link.dart` con `String downloadLinkFrom(String apiBaseUrl)`, que hace pasar T002, y `final downloadLinkProvider = Provider<String>((ref) => downloadLinkFrom(const String.fromEnvironment('API_BASE_URL')));` (R2)
- [X] T006 [P] [US1] Crear `app/lib/core/share/share_port.dart` con `abstract class SharePort { Future<void> share(String text); }`, la implementación `SharePlusPort` sobre `SharePlus.instance.share(ShareParams(text: text))` y `final sharePortProvider = Provider<SharePort>((ref) => SharePlusPort());` (R1). Si el usuario cancela el selector, no se lanza nada
- [X] T007 [P] [US1] Añadir a `app/lib/l10n/app_es.arb` las claves `menuShareApp` («Compartir Mykcal»), `shareTitle` («Compartir Mykcal»), `shareIntro` («Envía este enlace para que descarguen la app. Para crear la cuenta necesitarán un código de invitación.»), `shareCopy` («Copiar»), `shareSend` («Compartir»), `shareCopied` («Enlace copiado»), `shareCopyFailed` («No se pudo copiar el enlace») y `shareText` con el placeholder `{link}` («Prueba Mykcal, la app para registrar lo que comes: {link}»). Regenerar con `flutter gen-l10n` en `app/`
- [X] T008 [US1] Crear `app/lib/features/share/share_app_sheet.dart` con `Future<void> showShareAppSheet(BuildContext context)` (`showModalBottomSheet`) y el widget `ShareAppSheet` según `contracts/ui-flows.md`: encabezado con `Semantics(header: true)`, `SelectableText` del enlace, `OutlinedButton` «Copiar» (`Clipboard.setData`; `SnackBar` de éxito o de error, R5) y `FilledButton` «Compartir» (`sharePortProvider`, con `l10n.shareText(link)`). Respeta el tamaño de texto del sistema y no usa la red (depende de T005–T007)
- [X] T009 [US1] En `app/lib/features/home/home_screen.dart`, añadir `_MenuAction.shareApp` y su `PopupMenuItem` (`l10n.menuShareApp`) entre «Invitaciones» y «Cerrar sesión», visible para todos, que llama a `showShareAppSheet(context)` (depende de T008)

**Checkpoint**: T002–T004 en verde; la hoja funciona en el emulador en modo avión.

---

## Phase 4: User Story 2 - Alta del administrador sin código (Priority: P2)

**Goal**: el administrador continúa con el campo vacío; un no administrador con código vacío recibe «Escribe el código de invitación.» sin que cuente como intento.

**Independent Test**: escenarios 6–8 de `quickstart.md`.

### Tests for User Story 2 ⚠️ (escribir primero y comprobar que fallan)

- [X] T010 [P] [US2] En `backend/tests/integration/test_registration.py`:
  - un no administrador con `{"invitation_code": ""}` y con `{"invitation_code": " - "}` (vacío tras normalizar) recibe `400` y `code == "INVITATION_REQUIRED"`, sin fila en `user_account`;
  - la respuesta valida contra `openapi.yaml` con el helper de `backend/tests/contract/schema.py`;
  - ya registrado con código vacío sigue dando `409 ALREADY_REGISTERED`.

  El caso del administrador con `""` ya está en `test_invitation_admin.py:76`; comprobar que sigue en verde.
- [X] T011 [P] [US2] En `backend/tests/integration/test_registration_throttle.py`:
  - 5 envíos de código vacío de un no administrador no crean filas en `registration_failure` y el siguiente código erróneo da `400 INVITATION_INVALID`, no `429` (FR-010);
  - con un bloqueo activo previo, el código vacío devuelve `400 INVITATION_REQUIRED` (se evalúa antes del bloqueo, `contracts/api-changes.md`).
- [X] T012 [P] [US2] En `app/test/registration/code_screen_test.dart`:
  - con el campo vacío, «Continuar» está habilitado;
  - se muestra la ayuda «Si eres el administrador, puedes dejarlo vacío.»;
  - un `ApiError('INVITATION_REQUIRED', 400)` muestra «Escribe el código de invitación.»;
  - durante una espera por `TOO_MANY_ATTEMPTS`, el botón sigue deshabilitado aunque el campo esté vacío.

### Implementation for User Story 2

- [X] T013 [US2] Añadir `INVITATION_REQUIRED = "INVITATION_REQUIRED"` a `ErrorCode` en `backend/src/mykcal/core/errors.py`
- [X] T014 [US2] En `backend/src/mykcal/accounts/service.py`, dentro de `if not is_admin:` y **antes** de `throttle.active_block`, añadir: si `codes.normalize(raw_code) == ""`, `raise ApiError(400, ErrorCode.INVITATION_REQUIRED, "Escribe el código de invitación.")`, sin llamar a `throttle.register_failure`. Hace pasar T010–T011 (depende de T013)
- [X] T015 [P] [US2] En `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, según `contracts/api-changes.md`:
  - la descripción del `400` de `POST /v1/registration` pasa a «INVITATION_INVALID (…) o INVITATION_REQUIRED (código vacío de un usuario que no es administrador; no cuenta como intento)»;
  - se añade `INVITATION_REQUIRED` al `enum` de `ErrorBody.code`;
  - la descripción de `invitation_code` aclara que la cadena vacía solo crea cuenta al administrador.
- [X] T016 [P] [US2] Añadir a `app/lib/l10n/app_es.arb` `codeAdminHint` («Si eres el administrador, puedes dejarlo vacío.») y `errInvitationRequired` («Escribe el código de invitación.»), y regenerar con `flutter gen-l10n`. Si T007 está en curso, coordinar el mismo archivo
- [X] T017 [US2] En `app/lib/features/registration/registration_controller.dart`, añadir `RegistrationProblem.required` y mapear `'INVITATION_REQUIRED'` a ese valor en `submit()`
- [X] T018 [US2] En `app/lib/features/registration/code_screen.dart` (depende de T016–T017):
  - `canSubmit = !reg.busy && !waiting`, sin exigir texto (FR-007);
  - mostrar `l10n.codeAdminHint` bajo `l10n.codeHelp`;
  - mapear `RegistrationProblem.required` a `l10n.errInvitationRequired`.

**Checkpoint**: T010–T012 en verde; el escenario 6 se prueba en el móvil con una cuenta nueva o con la base vacía.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T019 [P] En `backend/`, ejecutar `uv run ruff check`, `uv run ruff format --check` y `uv run pytest` (incluido `-m privacy`; la lista de rutas públicas no cambia)
- [X] T020 [P] En `app/`, ejecutar `flutter analyze` y `flutter test` y corregir los avisos
- [X] T021 Actualizar `specs/001-acceso-y-despliegue/contracts/ui-flows.md`: añadir la entrada «Compartir Mykcal» al menú de inicio y el cambio de la pantalla del código, con enlace a `specs/008-compartir-app-y-alta-admin/contracts/ui-flows.md`
- [ ] T022 Compilar con `app/scripts/build_apk.sh prod`, instalar en el móvil con `adb install -r` y recorrer los escenarios 1–9 de `specs/008-compartir-app-y-alta-admin/quickstart.md`, anotando el resultado en el PR. **Pendiente**: APK compilado (`app-prod-release.apk`, 53.4 MB) desde `008` el 2026-11-25; falta instalarlo y recorrer los escenarios con el móvil conectado
- [X] T023 Cuando el PR #3 (001 → `dev`) esté fusionado, abrir el PR de `008-compartir-app-y-alta-admin` → `dev`. **Hecho sin PR nuevo**: el PR #3 está fusionado y el commit `287f6c2` de la 008 ya está en `origin/dev` (PRs #4 y #5)

---

## Dependencies & Execution Order

- **Setup (T001)** solo bloquea a US1 (`share_plus`).
- **US1**: T002–T004 → T005–T007 (en paralelo) → T008 → T009.
- **US2**: T010–T012 → T013 → T014; T015–T016 en paralelo; T017 → T018.
- **US1 y US2** son independientes entre sí. Su único archivo compartido es `app_es.arb` (T007 y T016).
- **Polish**: tras las dos historias.

## Parallel Example: User Story 1

```text
T002 download_link_test.dart   |  T003 share_app_sheet_test.dart  |  T004 home_menu_test.dart
T005 download_link.dart        |  T006 share_port.dart            |  T007 app_es.arb
```

## Parallel Example: User Story 2

```text
T010 test_registration.py  |  T011 test_registration_throttle.py  |  T012 code_screen_test.dart
T015 openapi.yaml          |  T016 app_es.arb
```

## Implementation Strategy

1. **MVP**: T001 + US1 (T002–T009). Con eso ya se puede compartir el enlace, que es lo que pidió Erick.
2. US2 (T010–T018), un cambio pequeño y autocontenido.
3. Polish (T019–T023): APK en el móvil y PR a `dev`.
