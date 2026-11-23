# Research: 002 — Onboarding, objetivo diario y baja

Decisiones técnicas de la feature. Las reglas de cálculo están cerradas en la sección
*Clarifications* de la spec. Aquí solo se decide **cómo** se implementan.

---

## R1. El cálculo vive solo en el backend, como función pura

**Decisión**: un módulo `mykcal/targets/calc.py` con una función pura
`calculate(inputs: CalcInputs) -> CalcResult`. No hace E/S, no lee el reloj y no usa la base de
datos. La app no calcula el objetivo: lo recibe del API.

**Rationale**: el principio VI exige funciones puras y deterministas con pruebas de casos
conocidos. Con una sola implementación no hay dos versiones de la fórmula que puedan divergir.
La app ya requiere conexión (restricción técnica), así que el cálculo en el servidor no limita nada.

**Alternativas**: duplicar el cálculo en Dart para mostrar el objetivo sin red. Se rechaza porque
duplica la lógica y obliga a mantener dos baterías de pruebas.

## R2. Aritmética con `Decimal` y redondeo «mitad hacia arriba» al final

**Decisión**:
- Todo el cálculo se hace con `decimal.Decimal` y los valores intermedios **sin redondear**.
- Solo al final se redondea cada valor a la unidad con `ROUND_HALF_UP`.
- Los carbohidratos se calculan sobre las kcal sin redondear:
  `carbs = (kcal − 4·proteína − 9·grasa) / 4`, con `grasa = 0,25·kcal / 9`. Si el resultado es
  negativo, queda en 0.
- El mínimo de 1.500 kcal (hombre) o 1.200 kcal (mujer) se aplica a las kcal objetivo **antes**
  de calcular la grasa y los carbohidratos.

**Rationale**: `round()` de Python redondea «al par» (`round(0.5) == 0`) y `float` arrastra errores
binarios (`1780 * 1.55 = 2758.9999…`). Con `Decimal` y `ROUND_HALF_UP`, los casos de la spec dan
exactamente los valores esperados:

| Caso | Gasto | kcal | Proteína | Grasa | Carbohidratos |
|---|---|---|---|---|---|
| H 30 a, 180 cm, 80 kg, moderada, mantener | 2.759 | 2.759 | 144 | 77 (76,64) | 373 (373,31) |
| Igual, perder grasa | 2.759 | 2.207 (2.207,2) | 176 | 61 (61,31) | 238 (237,85) |

**Alternativas**: redondear cada paso. Se rechaza porque acumula errores y hace que el resultado
dependa del orden de las operaciones.

## R3. Avisos del cálculo como lista de códigos

**Decisión**: `CalcResult` incluye `notices: list[str]` con dos códigos posibles:
- `MIN_KCAL_APPLIED`: se fijó el mínimo seguro de kcal.
- `CARBS_CLAMPED`: los carbohidratos salían negativos y quedan en 0; el objetivo no es coherente.

Los avisos se guardan con el objetivo calculado (`calc_notices`). La app muestra un texto propio
para cada código.

**Rationale**: así la app puede explicar el motivo (edge cases de la spec) sin conocer la fórmula.

## R4. El objetivo se guarda como historial de versiones

**Decisión**: tabla `daily_target` con una fila por versión. Cada cálculo, recálculo o edición
manual inserta una fila nueva con `is_current = true` y marca la anterior como `false`. Un índice
único parcial garantiza una sola versión vigente por usuario. Las versiones anteriores nunca se
borran.

**Rationale**: la feature 004 compara cada día con «el objetivo vigente ese día» (FR-011 de 004).
Si aquí se sobrescribiera una fila única, esa historia se perdería y habría que migrar datos más
adelante. El coste ahora es pequeño: una columna `effective_from` y un índice.

**Alternativas**: una fila por usuario con `UPDATE`. Es más simple hoy, pero rompe la 004.

## R5. Datos del cálculo guardados en la propia versión del objetivo (FR-013)

**Decisión**: cada fila de `daily_target` guarda los datos con los que se calculó:
`calc_weight_kg`, `calc_age`, `calc_sex`, `calc_height_cm`, `calc_activity`, `calc_goal` y
`calculated_at`. Una edición manual copia esos datos de la versión anterior, porque no cambia la
base del cálculo.

**Rationale**: la 007 compara la media semanal con «el peso usado en el último cálculo» y lo lee de
aquí. El objetivo sigue siendo autoexplicativo aunque el perfil cambie después.

## R6. El peso no se guarda en el perfil

**Decisión**: `user_profile` no tiene columna de peso. El peso vive en `weight_entry`, con un
registro por usuario y día (`UNIQUE (user_id, measured_on)`), como pide la 007. El «peso actual»
del perfil es el del registro con la fecha más reciente. El «peso usado en el cálculo» es
`daily_target.calc_weight_kg` (FR-006).

- La fecha del registro (`measured_on`) la envía la app: es la fecha local del móvil. Así el día
  coincide con el del usuario sin configurar zonas horarias en el servidor. El servidor rechaza
  fechas más de 1 día posteriores a la suya en UTC.
- Si se cambia el peso al editar el perfil, se crea o se sustituye el registro de ese día.

**Rationale**: una sola fuente para el peso y compatible con la 007 sin migraciones.

## R7. Edad guardada tal cual, no fecha de nacimiento

**Decisión**: se guarda `age` (18–100), como dice la spec. No se pide fecha de nacimiento.

**Consecuencia aceptada**: la edad no avanza sola. El usuario la corrige en el perfil; el efecto
sobre el gasto es de unas 5 kcal por año.

**Alternativas**: pedir el año de nacimiento. Se rechaza porque cambia lo que pide la spec y
añade un dato personal más (la spec dice que solo se pide lo necesario).

## R8. Consentimiento: texto en la app, versión comprobada en el servidor

**Decisión**:
- El texto del consentimiento está en `app_es.arb`, junto a una constante
  `consentTextVersion` (por ejemplo, `"2026-11-1"`).
- El backend tiene la constante `CURRENT_CONSENT_VERSION` y acepta `POST /v1/consent` solo si la
  versión enviada coincide. Si no, responde `409 CONSENT_VERSION_MISMATCH`: la app está
  desactualizada.
- Se guarda una fila en `health_consent` con `user_id`, `text_version` y `accepted_at` (hora del
  servidor). Repetir la petición con la misma versión es idempotente.
- **En el MVP vale cualquier consentimiento registrado**. Un cambio de versión del texto no obliga a
  aceptarlo de nuevo; la versión sirve para saber qué texto se aceptó (FR-003).

**Rationale**: la hora la pone el servidor, que es la fuente de verdad. La comprobación de versión
impide registrar un texto que el servidor no conoce.

**Pendiente de Erick**: la redacción del texto (supuesto de la spec).

## R9. Puerta de consentimiento en el backend: dependencia `require_consent`

**Decisión**: una dependencia nueva `require_consent` encadenada tras `require_active_account`.
Responde `403 CONSENT_REQUIRED` si el usuario no tiene ninguna fila en `health_consent`. La usan
**todas** las rutas de datos de salud: perfil, objetivo y, en el futuro, peso y comidas.

- Una prueba `privacy` recorre las rutas y comprueba que todas las de la lista de datos de salud
  usan la dependencia. Las rutas nuevas de otras features entran en esa lista por defecto (FR-002,
  SC-003).
- `POST /v1/consent` y `POST /v1/me/deactivation` exigen cuenta activa pero no consentimiento.

**Rationale**: el principio IV es NON-NEGOTIABLE. Una puerta en el servidor no depende de que la app
se comporte bien.

## R10. Estado del onboarding en `GET /v1/me`

**Decisión**: `Me` incluye `onboarding` con uno de tres valores, calculado en cada petición:
- `consent`: falta el consentimiento.
- `profile`: hay consentimiento pero falta perfil (y por tanto objetivo).
- `done`: hay perfil y objetivo vigente.

La app decide la pantalla con ese valor. Si se cierra a mitad del onboarding, al volver continúa
en el paso pendiente (edge case de la spec).

- El borrador del formulario de perfil vive en un `Notifier` mientras la app está abierta. No se
  guarda en el móvil: si se cierra la app, se vuelve a escribir. Así no quedan datos de salud en el
  móvil fuera del flujo normal.

**Rationale**: una sola petición al abrir la app basta para elegir la pantalla; no hay estado de
onboarding que guardar.

## R11. Perfil y objetivo inicial en una sola transacción

**Decisión**: `PUT /v1/profile` crea o actualiza el perfil. La primera vez, en la misma transacción:
1. guarda el perfil;
2. crea el registro de peso de `measured_on`;
3. calcula y guarda la primera versión del objetivo (`source = calculated`).

Responde con el perfil, el objetivo vigente y, si aplica, una propuesta de recálculo (R12).

**Rationale**: nunca queda un perfil sin objetivo; `onboarding` pasa de `profile` a `done` de una
vez.

## R12. Recálculo al cambiar el perfil (US2.4, US3.2, FR-015)

**Decisión**: tras guardar un perfil que ya existía, el servidor compara los datos del cálculo
vigente (`calc_*`) con los **del formulario enviado**: edad, sexo, altura, actividad, objetivo y el
`weight_kg` de esa petición. El peso solo cuenta como cambio si difiere del último registro de peso
**antes** de guardar (es decir, si el usuario lo ha cambiado en el formulario). Los registros de peso
de la 007 no disparan recálculos aquí: el recálculo por peso es de la 007 (supuesto de la spec).
- **Sin cambios relevantes**: no hace nada.
- **Objetivo `calculated`**: recalcula y guarda una nueva versión en la misma transacción. Responde
  `recalculation: {status: "applied", previous: …}` para que la app muestre el antes y el después.
- **Objetivo `manual`**: **no** recalcula. Responde
  `recalculation: {status: "proposed", proposed: …}` con el objetivo que saldría, sin guardarlo. Si
  el usuario acepta, la app llama a `POST /v1/target/recalculate`. Si no acepta, no se llama a nada
  y el objetivo se mantiene.

`POST /v1/target/recalculate` calcula con el perfil y el peso actuales y guarda una versión
`calculated`. Sirve también para «volver al cálculo automático» (FR-016, US3.3).

`recalculate(session, user_id, now, weight_kg=None)`: sin `weight_kg` usa el peso del último
registro. La 007 le pasará la media semanal.

**Rationale**: la regla de «no recalcular sin confirmación» se cumple en el servidor y no depende de
la app. La propuesta no se guarda, así que no hay estado intermedio que limpiar.

**Decidido en *Clarifications* 2026-11-23**: con objetivo calculado, recálculo automático con aviso
del cambio; con objetivo manual, propuesta y confirmación.

## R13. Edición manual del objetivo (FR-014, FR-017)

**Decisión**: `PUT /v1/target` recibe los 12 valores completos (enteros ≥ 0; kcal ≥ 1) y guarda una
versión `manual`. La app envía todos los valores aunque el usuario cambie solo uno.

- El aviso de macros incoherentes (más de un 5% de diferencia entre `4·P + 4·C + 9·G` y las kcal) lo
  calcula **la app** en vivo mientras se edita, con una función pura en Dart probada. No bloquea el
  guardado. El servidor no lo comprueba: es un aviso de interfaz, no una regla de datos.
- Límites superiores de saneamiento en el servidor (por ejemplo, kcal ≤ 10.000) para rechazar
  errores de escritura con `VALIDATION_ERROR`.

## R14. Errores de validación por campo

**Decisión**: la app valida los rangos de la spec antes de enviar y muestra el rango junto al campo
(US1.5). El servidor aplica los mismos rangos con Pydantic y responde `400 VALIDATION_ERROR` con un
campo nuevo opcional `fields: [nombre, …]` en `ErrorBody`, sin los valores enviados.

**Rationale**: la validación en la app da respuesta inmediata; la del servidor es la garantía. Los
nombres de campo permiten marcar el campo correcto si la app y el servidor no coinciden.

## R15. Baja: desactivar en Mykcal, no en Zitadel

**Decisión**: `POST /v1/me/deactivation` pone `status = 'disabled'` y `disabled_at = now()` en
`user_account`. Responde `204`. Después, la app llama a `signOut()` de la 001 (revoca tokens y
borra la sesión) y muestra la pantalla de acceso con el aviso «Tu cuenta se ha dado de baja».

- El usuario de Zitadel **no** se toca: Mykcal no tiene credenciales de su Management API (R1 de la
  001). Si vuelve a entrar, `GET /v1/me` devuelve `status: disabled` y la app muestra la pantalla de
  cuenta desactivada que ya existe (US4.3).
- Cualquier token que siga vivo en otro dispositivo queda rechazado por `require_active_account`
  (`403 ACCOUNT_DISABLED`).
- La plaza se libera sola: el contador de la 001 solo cuenta cuentas `active`.
- Se toma el bloqueo consultivo de la 001 (R7) para que la baja no se cruce con un alta que cuenta
  plazas.
- Se registra el evento `account_deactivated` con el `user_id` interno, sin `sub`.

**Rationale**: cumple FR-019 y la restricción «baja = desactivar, sin borrado» sin dependencias
nuevas.

## R16. Navegación de la app

**Decisión**:
- `AppGate` sigue eligiendo la pantalla por el estado de la cuenta. Para `Active(me)` mira
  `me.onboarding`: `consent` → `ConsentScreen`, `profile` → `ProfileScreen` (modo onboarding),
  `done` → `HomeScreen`.
- Al guardar el perfil del onboarding se muestra `TargetScreen` (resultado). «Empezar» vuelve a
  pedir `/v1/me`, y el gate lleva a inicio.
- Inicio sustituye el texto provisional por una tarjeta con el objetivo (kcal y macros) y un acceso
  «Ver detalle» a `TargetScreen`, que muestra fibra y micros y permite editar.
- El menú de inicio añade **Ajustes**: «Mi perfil», «Mi objetivo» y «Darse de baja».

**Rationale**: reutiliza el gate y el menú de la 001 y la 008 sin añadir un paquete de rutas.

## R17. Sin dependencias nuevas

**Decisión**: ninguna dependencia nueva en el backend ni en la app. `Decimal` es de la librería
estándar; los formularios usan `Form` y `TextFormField` de Flutter; los números se formatean con
`intl`, que ya está (`NumberFormat` con locale `es`: `2.759 kcal`, `78,4 kg`).

**Entrada decimal en español**: el campo de peso acepta coma o punto y la app normaliza a punto
antes de enviar.
