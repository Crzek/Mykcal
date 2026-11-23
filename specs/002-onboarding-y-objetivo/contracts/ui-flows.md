# Flujos de interfaz

Este documento completa `specs/001-acceso-y-despliegue/contracts/ui-flows.md`. Todos los textos van
en `app_es.arb`. Todos los controles tienen etiqueta para el lector de pantalla, miden al menos
48 dp y respetan el tamaño de texto del sistema (FR-020, principio VIII).

## Puerta de la app (`AppGate`)

| Estado | `me.onboarding` | Pantalla |
|---|---|---|
| `Active` | `consent` | Consentimiento |
| `Active` | `profile` | Perfil (modo onboarding) |
| `Active` | `done` | Inicio |
| `Disabled` | — | Cuenta desactivada (de 001, sin cambios) |

Los demás estados de la 001 no cambian.

## 1. Consentimiento

```
┌──────────────────────────────────────────┐
│ Tus datos de salud                       │  ← encabezado
│                                          │
│ [Texto del consentimiento, con scroll]   │  ← redacta Erick (research R8)
│                                          │
│ ☐ He leído y acepto el tratamiento de    │  ← CheckboxListTile
│   mis datos de salud                     │
│                                          │
│ [ Aceptar y continuar ]                  │  ← FilledButton, deshabilitado sin ☑
│ [ Cerrar sesión ]   [ Darme de baja ]    │  ← TextButton; el 2.º abre el diálogo de la pantalla 7
└──────────────────────────────────────────┘
```

| Acción | Resultado |
|---|---|
| Aceptar con ☑ | `POST /v1/consent` → `/v1/me` → pantalla de perfil |
| No marcar | El botón sigue deshabilitado; salidas: cerrar sesión o darse de baja (US1.2) |
| No quiero aceptar | «Darme de baja» → diálogo de la pantalla 7 → libera la plaza |
| Sin conexión | `SnackBar` «Sin conexión. Inténtalo de nuevo.»; la casilla sigue marcada |
| `CONSENT_VERSION_MISMATCH` | «Actualiza la app para continuar.» |

## 2. Perfil (onboarding y edición)

```
┌──────────────────────────────────────────┐
│ Tu perfil                                │
│ Edad          [ 30 ] años                │  ← TextFormField numérico
│ Sexo          (•) Hombre  ( ) Mujer      │  ← SegmentedButton
│               Solo se usa para el cálculo│
│ Altura        [ 180 ] cm                 │
│ Peso          [ 80,0 ] kg                │  ← acepta coma o punto
│ Actividad     ▼ Moderada: 3–5 días/sem.  │  ← lista de 5 niveles con descripción
│ Objetivo      (•) Perder grasa           │  ← RadioListTile ×3
│               ( ) Mantener               │
│               ( ) Ganar músculo          │
│ [ Calcular mi objetivo ]                 │  ← en edición: «Guardar»
└──────────────────────────────────────────┘
```

**Validación** (US1.5): se valida al pulsar el botón y al salir de cada campo. El error va bajo el
campo y el lector de pantalla lo anuncia.

| Campo | Mensaje |
|---|---|
| Edad | «Entre 18 y 100 años» |
| Altura | «Entre 100 y 250 cm» |
| Peso | «Entre 30 y 300 kg, con un decimal como máximo» |
| Vacío | «Obligatorio» |

**Al guardar**:

| Situación | Resultado |
|---|---|
| Onboarding, `recalculation.status = created` | Pantalla de objetivo en modo resultado |
| Edición, `none` | `SnackBar` «Perfil guardado» y vuelta atrás |
| Edición, `applied` | Diálogo «Tu objetivo se ha actualizado» con antes → después de kcal y macros; [Aceptar] |
| Edición, `proposed` | Diálogo «Tu objetivo está editado a mano. ¿Recalcularlo con tus datos nuevos?» con actual → propuesto; [Mantener el mío] / [Recalcular]. «Recalcular» llama a `POST /v1/target/recalculate` |
| Sin conexión o error | `SnackBar` con el motivo; los valores siguen en pantalla |
| `VALIDATION_ERROR` con `fields` | Marca esos campos con su mensaje de rango |

## 3. Objetivo (resultado y detalle)

```
┌──────────────────────────────────────────┐
│ Tu objetivo diario                       │
│ ⓘ Editado a mano                         │  ← solo si source = manual
│                                          │
│ 2.759 kcal                               │  ← grande
│ Proteína        144 g                    │
│ Carbohidratos   373 g                    │
│ Grasa            77 g                    │
│                                          │
│ Fibra y micronutrientes                  │
│ Fibra           30 g    mínimo           │
│ Sodio        2.000 mg   máximo           │
│ Potasio      3.500 mg   mínimo           │
│ …                                        │
│                                          │
│ ⚠ Hemos subido tus calorías al mínimo    │  ← si MIN_KCAL_APPLIED
│   seguro de 1.500 kcal.                  │
│ ⚠ Tus macros no cuadran con las calorías.│  ← si CARBS_CLAMPED
│                                          │
│ [ Empezar ]                              │  ← modo resultado
│ [ Editar ]  [ Volver al cálculo ]        │  ← modo detalle; el 2.º solo si manual
└──────────────────────────────────────────┘
```

- Números con formato español (`NumberFormat('#,##0', 'es')`): `2.759`.
- «mínimo» y «máximo» van como texto, no solo con color.
- Los avisos usan icono y texto, nunca solo color.
- «Volver al cálculo» pide confirmación y llama a `POST /v1/target/recalculate` (US3.3).

## 4. Editar objetivo

Formulario con los 12 valores (enteros) y la unidad al lado de cada uno.

- **Aviso en vivo** (FR-017): si `|4·P + 4·C + 9·G − kcal| / kcal > 0,05`, se muestra bajo las kcal
  «Las calorías de tus macros (2.540 kcal) no coinciden con tu objetivo (2.759 kcal).». No
  deshabilita «Guardar».
- Valor vacío, negativo o no entero → «Escribe un número entero de 0 o más» (kcal: «de 1 o más»).
- «Guardar» → `PUT /v1/target` → `SnackBar` «Objetivo guardado» y vuelta al detalle, que ya muestra
  «Editado a mano».

## 5. Inicio (cambio)

- El texto provisional de la 001 se sustituye por una tarjeta «Tu objetivo de hoy» con kcal,
  proteína, carbohidratos y grasa, y un botón «Ver detalle» que abre la pantalla 3 en modo detalle.
- La tarjeta lee `GET /v1/target`. Si falla, muestra el error de conexión con «Reintentar».

### Menú (⋮)

| Entrada | Visible para | Acción |
|---|---|---|
| Invitaciones | Administrador | Sin cambios |
| Compartir Mykcal | Todos | Sin cambios (008) |
| **Ajustes** | Todos | Abre la pantalla de ajustes |
| Cerrar sesión | Todos | Sin cambios |

## 6. Ajustes

Lista con tres entradas: «Mi perfil» (pantalla 2 en modo edición), «Mi objetivo» (pantalla 3 en
modo detalle) y «Darse de baja», en color de error y separada del resto.

## 7. Darse de baja

Diálogo de confirmación (US4.1):

> **¿Darte de baja de Mykcal?**
> Tu cuenta se desactivará y no podrás volver a entrar. Tus datos se conservan, pero no podrás
> verlos ni recuperar la cuenta desde la app.
>
> [Cancelar] [Darme de baja]

- «Darme de baja» usa el color de error y no es la acción por defecto.
- Confirmar → `POST /v1/me/deactivation` → `signOut()` → pantalla de acceso con el aviso «Tu cuenta
  se ha dado de baja.».
- Error de red → `SnackBar`; la cuenta sigue activa y el usuario sigue en ajustes.
- Si después vuelve a iniciar sesión, ve la pantalla «Cuenta desactivada» de la 001 (US4.3).
