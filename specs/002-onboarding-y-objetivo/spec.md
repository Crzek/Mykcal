# Feature Specification: Onboarding, objetivo diario y baja

**Feature Branch**: `002-onboarding-y-objetivo`

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "002-onboarding-y-objetivo: consentimiento, perfil, cálculo del objetivo, edición y baja (desactivar cuenta). Épicas E2, E3 y E10."

## Clarifications

### Session 2026-11-22

- Q: ¿Qué fórmula de gasto diario y qué factores de actividad? → A: Mifflin-St Jeor por el factor de
  actividad (1,2 / 1,375 / 1,55 / 1,725 / 1,9).
- Q: ¿Qué ajuste calórico por objetivo? → A: perder grasa −20%, mantener 0%, ganar músculo +10%.
- Q: ¿Proteína por kilo y mínimo de grasa? → A: proteína 2,2 g/kg (perder), 1,8 g/kg (mantener),
  2,0 g/kg (ganar); grasa mínimo el 25% de las kcal; el resto, carbohidratos.
- Q: ¿Cuáles son los micros clave? → A: sodio, potasio, calcio, hierro, magnesio, vitamina D y
  vitamina C, además de la fibra.
- Q: ¿Se puede reactivar una cuenta desactivada? → A: no desde la app en el MVP; los datos se
  conservan sin plazo (riesgo aceptado).

### Session 2026-11-23

- Q: Al cambiar el perfil con un objetivo calculado, ¿se pregunta antes de recalcular? → A: no; se
  recalcula automáticamente y se muestra el objetivo anterior y el nuevo. Solo se pregunta si el
  objetivo está editado a mano.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consentimiento y perfil (Priority: P1)

Tras registrarse, el usuario acepta de forma explícita el tratamiento de sus datos de salud y
completa su perfil: edad, sexo, altura, peso, actividad física semanal y objetivo físico (perder
grasa, mantener o ganar músculo).

**Why this priority**: sin consentimiento no se puede guardar ningún dato de salud y sin perfil no
hay objetivo; bloquea el resto de la app.

**Independent Test**: con una cuenta nueva, rechazar el consentimiento (no se avanza ni se guarda
nada), aceptarlo, completar el perfil y comprobar que queda guardado.

**Acceptance Scenarios**:

1. **Given** un usuario recién registrado, **When** abre la app, **Then** se le muestra la pantalla
   de consentimiento antes que cualquier otra función.
2. **Given** la pantalla de consentimiento, **When** el usuario no acepta, **Then** no puede
   continuar y no se guarda ningún dato de salud.
3. **Given** el usuario acepta, **When** se registra el consentimiento, **Then** queda guardado con
   su fecha y hora y la versión del texto aceptado.
4. **Given** el consentimiento aceptado, **When** el usuario introduce sus datos válidos y el
   objetivo, **Then** el perfil queda guardado.
5. **Given** un dato fuera de rango (por ejemplo, altura 30 cm), **When** intenta continuar,
   **Then** se le indica el rango válido junto al campo y no se guarda.

---

### User Story 2 - Ver el objetivo diario calculado (Priority: P1)

Al terminar el perfil, la app muestra el objetivo diario: calorías, proteína, carbohidratos, grasa,
fibra y los 7 micros clave, calculados a partir de sus datos y su objetivo.

**Why this priority**: es el valor central de la app: saber cuánto comer.

**Independent Test**: introducir un perfil de referencia y comprobar que el objetivo coincide con
el resultado esperado de las reglas de cálculo.

**Acceptance Scenarios**:

1. **Given** un perfil completo, **When** termina el onboarding, **Then** ve su objetivo diario con
   calorías, macros, fibra y micros.
2. **Given** un hombre de 30 años, 180 cm, 80 kg, actividad moderada y objetivo mantener,
   **When** se calcula el objetivo, **Then** el gasto es 2.759 kcal (1.780 × 1,55), el objetivo
   2.759 kcal, la proteína 144 g, la grasa 77 g y los carbohidratos 373 g (redondeos a la unidad).
3. **Given** el mismo perfil con objetivo perder grasa, **When** se calcula, **Then** el objetivo
   es 2.207 kcal, proteína 176 g, grasa 61 g y carbohidratos 238 g.
4. **Given** un usuario que cambia su perfil (por ejemplo, actividad u objetivo), **When** guarda,
   **Then** si el objetivo no fue editado a mano se recalcula y se le muestra el anterior y el nuevo;
   si lo fue, se le propone recalcular y solo se recalcula si lo confirma.

---

### User Story 3 - Editar el objetivo a mano (Priority: P2)

El usuario sobrescribe cualquier valor del objetivo (por ejemplo, porque su nutricionista le marca
otras cifras). Un objetivo editado a mano no se recalcula sin su confirmación.

**Why this priority**: da control al usuario, pero el objetivo calculado ya cubre el caso básico.

**Independent Test**: editar las calorías y la proteína, cambiar el perfil y comprobar que el
objetivo editado no cambia sin confirmación.

**Acceptance Scenarios**:

1. **Given** un objetivo calculado, **When** el usuario edita uno o varios valores y guarda,
   **Then** se guardan y el objetivo queda marcado como editado a mano.
2. **Given** un objetivo editado a mano, **When** cambia algo que provocaría un recálculo,
   **Then** se le pregunta antes; si no acepta, su objetivo se mantiene.
3. **Given** un objetivo editado a mano, **When** el usuario pide volver al cálculo automático,
   **Then** se recalcula con sus datos actuales y deja de estar marcado como editado.
4. **Given** el usuario edita las calorías pero no los macros, **When** guarda, **Then** la app
   avisa si la suma de energía de los macros no coincide con las calorías (más de un 5% de
   diferencia), sin impedir guardar.

---

### User Story 4 - Darse de baja (Priority: P3)

El usuario pide darse de baja desde los ajustes. Tras confirmar, su cuenta se desactiva, se cierra
la sesión y no puede volver a entrar.

**Why this priority**: necesario pero de uso excepcional.

**Independent Test**: darse de baja, comprobar que la sesión se cierra, que no se puede volver a
iniciar sesión y que el servidor rechaza sus peticiones.

**Acceptance Scenarios**:

1. **Given** un usuario activo en ajustes, **When** pide darse de baja, **Then** se le explica que
   la cuenta se desactiva, que no podrá volver a entrar y que sus datos se conservan, y se le pide
   confirmación.
2. **Given** el usuario confirma, **When** se procesa la baja, **Then** la cuenta pasa a
   desactivada, se cierra la sesión y deja de contar para el límite de 50 cuentas.
3. **Given** una cuenta desactivada, **When** intenta iniciar sesión, **Then** se le deniega con un
   mensaje que lo explica.

---

### Edge Cases

- **Usuario cierra la app a mitad del onboarding**: al volver, continúa donde lo dejó; sin
  consentimiento no se ha guardado nada.
- **Carbohidratos resultantes negativos** (proteína + grasa mínima superan las calorías): los
  carbohidratos quedan en 0 y la app avisa de que el objetivo no es coherente.
- **Objetivo por debajo de un mínimo seguro**: si el cálculo da menos de 1.500 kcal (hombre) o
  1.200 kcal (mujer), se fija en ese mínimo y se explica el motivo.
- **Menores de edad**: no se admite una edad inferior a 18 años.
- **Sin conexión al guardar**: se avisa y los datos introducidos siguen en pantalla.
- **Editar un valor a un número no válido** (negativo o vacío): se rechaza con mensaje junto al
  campo.

## Requirements *(mandatory)*

### Functional Requirements

**Consentimiento**

- **FR-001**: El sistema MUST pedir consentimiento explícito para el tratamiento de datos de salud
  antes de cualquier otra función de la app.
- **FR-002**: El sistema MUST NOT guardar ningún dato de salud (perfil, peso, comidas) de un usuario
  sin un consentimiento registrado.
- **FR-003**: El sistema MUST registrar el consentimiento con fecha y hora y la versión del texto
  aceptado.

**Perfil**

- **FR-004**: Los usuarios MUST poder introducir y modificar: edad (18–100 años), sexo (hombre o
  mujer, para el cálculo), altura (100–250 cm), peso (30–300 kg, con un decimal), actividad
  semanal y objetivo físico.
- **FR-005**: La actividad semanal MUST elegirse entre cinco niveles con su descripción:
  sedentario (1,2), ligera 1–3 días/semana (1,375), moderada 3–5 días/semana (1,55), alta 6–7
  días/semana (1,725) y muy alta, trabajo físico o dos sesiones al día (1,9).
- **FR-006**: El peso introducido en el perfil MUST guardarse también como el primer registro de
  peso del usuario y como "peso usado en el cálculo".

**Cálculo del objetivo**

- **FR-007**: El sistema MUST calcular el metabolismo basal con Mifflin-St Jeor:
  10 × peso(kg) + 6,25 × altura(cm) − 5 × edad + 5 (hombre) o − 161 (mujer).
- **FR-008**: El gasto diario MUST ser el metabolismo basal por el factor de actividad.
- **FR-009**: El objetivo calórico MUST ser el gasto diario por 0,80 (perder grasa), 1,00
  (mantener) o 1,10 (ganar músculo), con un mínimo de 1.500 kcal (hombre) o 1.200 kcal (mujer).
- **FR-010**: La proteína MUST ser 2,2 g/kg (perder), 1,8 g/kg (mantener) o 2,0 g/kg (ganar) sobre
  el peso usado en el cálculo; la grasa, el 25% de las kcal (9 kcal/g); los carbohidratos, el resto
  (4 kcal/g; proteína 4 kcal/g), nunca negativos.
- **FR-011**: La fibra y los micros MUST tomar los valores de referencia de la tabla siguiente
  según el sexo:

  | Nutriente | Hombre | Mujer | Tipo |
  | --- | --- | --- | --- |
  | Fibra | 30 g | 25 g | mínimo |
  | Sodio | 2.000 mg | 2.000 mg | máximo |
  | Potasio | 3.500 mg | 3.500 mg | mínimo |
  | Calcio | 1.000 mg | 1.000 mg | mínimo |
  | Hierro | 8 mg | 18 mg (8 mg desde 51 años) | mínimo |
  | Magnesio | 400 mg | 310 mg | mínimo |
  | Vitamina D | 15 µg | 15 µg | mínimo |
  | Vitamina C | 90 mg | 75 mg | mínimo |

- **FR-012**: Los cálculos MUST ser deterministas: los mismos datos producen siempre el mismo
  objetivo. Los valores mostrados se redondean a la unidad.
- **FR-013**: El sistema MUST guardar con el objetivo los datos que se usaron para calcularlo
  (peso, perfil y fecha), para poder detectar cuándo conviene recalcular.

**Edición del objetivo**

- **FR-014**: Los usuarios MUST poder sobrescribir cualquier valor del objetivo; el objetivo queda
  marcado como editado a mano.
- **FR-015**: Un objetivo editado a mano MUST NOT recalcularse sin la confirmación del usuario.
- **FR-016**: Los usuarios MUST poder volver al objetivo calculado automáticamente.
- **FR-017**: La app MUST avisar, sin bloquear, cuando la energía de los macros difiera más de un
  5% de las calorías del objetivo.

**Baja**

- **FR-018**: Los usuarios MUST poder darse de baja desde los ajustes tras una confirmación
  explícita que explique las consecuencias.
- **FR-019**: La baja MUST desactivar la cuenta, cerrar la sesión y conservar los datos; la cuenta
  desactivada no puede iniciar sesión ni reactivarse desde la app.

**Transversales**

- **FR-020**: Todas las pantallas MUST estar en español, usar unidades métricas (kg, cm, g, mg, µg,
  kcal) y cumplir WCAG 2.1 AA.

### Key Entities

- **Consentimiento**: aceptación explícita del tratamiento de datos de salud. Atributos: usuario,
  fecha y hora, versión del texto.
- **Perfil**: edad, sexo, altura, nivel de actividad y objetivo físico de un usuario.
- **Objetivo diario**: calorías, proteína, carbohidratos, grasa, fibra y 7 micros. Atributos
  adicionales: origen (calculado o editado a mano), datos usados en el cálculo, fecha.
- **Registro de peso**: peso de un usuario en una fecha (el primero lo crea el onboarding).
- **Usuario** (de 001): pasa de activa a desactivada con la baja.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario nuevo completa consentimiento, perfil y ve su objetivo en menos de
  3 minutos.
- **SC-002**: El 100% de los casos de referencia del cálculo (al menos uno por sexo, objetivo y
  nivel de actividad, más los límites de mínimos) producen el resultado esperado.
- **SC-003**: 0 datos de salud guardados para usuarios sin consentimiento registrado.
- **SC-004**: El 100% de los objetivos editados a mano permanecen sin cambios si el usuario no
  confirma un recálculo.
- **SC-005**: El 100% de las cuentas dadas de baja quedan sin acceso inmediatamente.

## Assumptions

- La pantalla de clave de IA del onboarding se añade en la feature 006; en esta feature el
  onboarding termina en el objetivo.
- Los valores de micros siguen referencias habituales de ingesta para adultos (EFSA/IOM) y pueden
  ajustarse en el plan sin cambiar el alcance.
- El sexo solo se usa para el cálculo; no se piden otros datos personales.
- La proteína se calcula sobre el peso actual sin ajuste por composición corporal.
- El texto del consentimiento lo redacta Erick; la versión permite saber qué texto se aceptó.
- La propuesta de recálculo por cambio de peso es de la feature 007; aquí solo se recalcula por
  cambio de perfil.
- No hay plazo de conservación de datos de cuentas desactivadas (riesgo RGPD aceptado por Erick).
