# Contrato: pantallas y flujos de la app (001)

Todos los textos están en `lib/l10n/app_es.arb` (FR-016). Cada pantalla pasa las guías de
contraste y etiquetado en sus pruebas de widgets (FR-017, SC-007). Tema según el sistema.

## Máquina de estados de arranque

```
inicio → ¿tokens guardados?
  no → AccesoScreen
  sí → GET /v1/me (renueva el token si hace falta)
         200 active   → InicioScreen
         200 disabled → CuentaDesactivadaScreen
         404 ACCOUNT_NOT_REGISTERED → CodigoInvitacionScreen
         401 tras renovar → AccesoScreen
         red / 5xx → ErrorConexion (reintentar), sin perder el estado
```

## Pantallas

| Pantalla | Contenido | Acciones |
|---|---|---|
| **AccesoScreen** | Nombre de la app y una frase breve | «Iniciar sesión» y «Crear cuenta» abren la página de Zitadel (en registro, con el prompt `create`) |
| **CodigoInvitacionScreen** | Campo de código (acepta minúsculas y espacios), ayuda «Pídeselo a Erick» y «Si eres el administrador, puedes dejarlo vacío.» | «Continuar» (habilitado también con el campo vacío, 008) → `POST /v1/registration`; «Cerrar sesión» |
| **InicioScreen** | Saludo con `display_name` y la tarjeta «Tu objetivo de hoy» (002) | Menú: «Invitaciones» (solo si `is_admin`), «Compartir Mykcal» (todos, 008), «Ajustes» (todos, 002), «Cerrar sesión» |
| **InvitacionesScreen** (admin) | Código vigente como `ABCD-EFGH`, botón copiar, «N de 50 cuentas activas · M plazas libres» | «Cambiar código» (con confirmación en un diálogo de la app, no del sistema) |
| **CuentaDesactivadaScreen** | «Tu cuenta está desactivada» | «Cerrar sesión» |

## Mensajes por código de error

| Código API | Mensaje en pantalla |
|---|---|
| `INVITATION_INVALID` | «El código no es válido. Comprueba que es el último que te envió Erick.» |
| `INVITATION_REQUIRED` (008) | «Escribe el código de invitación.» |
| `NO_SEATS` | «Ahora mismo no hay plazas libres en Mykcal.» |
| `TOO_MANY_ATTEMPTS` | «Demasiados intentos. Podrás volver a probar en {tiempo}.» El botón queda desactivado con una cuenta atrás |
| `ACCOUNT_DISABLED` | Lleva a CuentaDesactivadaScreen |
| `FORBIDDEN` | «No tienes permiso para esto.» (no debería verse: la opción está oculta) |
| `AUTH_UNAVAILABLE` / 5xx / timeout | «El servidor no responde. Inténtalo de nuevo en unos minutos.» + Reintentar |
| Sin red | Banner «Necesitas conexión a Internet» + Reintentar. El campo conserva lo escrito |

## Sesión

- El access token se renueva en silencio antes de caducar o al recibir un 401.
- Si la renovación falla → AccesoScreen. Al volver a entrar, el borrador del código sigue ahí.
- **Cerrar sesión**: revocar + `end_session` (plazo de 5 s), borrar los tokens y volver a
  AccesoScreen.

> La hoja «Compartir Mykcal» y el cambio de la pantalla del código están detallados en
> `specs/008-compartir-app-y-alta-admin/contracts/ui-flows.md`.

> Onboarding (consentimiento, perfil, objetivo), ajustes y baja: ver
> `specs/002-onboarding-y-objetivo/contracts/ui-flows.md`. `AppGate` elige la pantalla con `Me.onboarding`.

> Búsqueda de alimentos, escáner de códigos de barras, detalle, alimentos personalizados y
> «Fuentes de datos»: ver `specs/003-base-de-alimentos/contracts/ui-flows.md`. Se abren desde el
> botón «Alimentos» de InicioScreen y desde Ajustes.
