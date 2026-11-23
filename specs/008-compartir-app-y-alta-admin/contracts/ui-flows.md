# Flujos de interfaz

Este documento completa `specs/001-acceso-y-despliegue/contracts/ui-flows.md`.

## Inicio → menú (⋮)

| Entrada | Visible para | Acción |
|---|---|---|
| Invitaciones | Administrador | Sin cambios |
| **Compartir Mykcal** | Todos los usuarios activos | Abre la hoja «Compartir Mykcal» |
| Cerrar sesión | Todos | Sin cambios |

## Hoja «Compartir Mykcal» (modal inferior)

```
┌──────────────────────────────────────────┐
│ Compartir Mykcal                         │  ← encabezado (Semantics header)
│ Envía este enlace para que descarguen    │
│ la app. Para crear la cuenta necesitarán │
│ un código de invitación.                 │
│                                          │
│ https://mykcal-bk-api.cruzerick.com/     │  ← SelectableText
│ descargar/mykcal.apk                     │
│                                          │
│ [ Copiar ]            [ Compartir ]      │  ← OutlinedButton / FilledButton
└──────────────────────────────────────────┘
```

| Acción | Resultado |
|---|---|
| Copiar | Portapapeles = enlace. `SnackBar` «Enlace copiado» |
| Copiar con error del sistema | `SnackBar` «No se pudo copiar el enlace»; la hoja sigue abierta |
| Compartir | Selector del sistema con el texto compartido (`data-model.md`) |
| Cancelar el selector | Sin mensaje; la hoja sigue abierta |
| Atrás / deslizar | Cierra la hoja |

- No llama a la red.
- Sus botones miden al menos 48 dp, llevan etiqueta y respetan el tamaño de texto del sistema.

## Pantalla del código de invitación (cambio)

- «Continuar» se habilita con el campo vacío. Solo se deshabilita mientras hay una petición en
  curso o una espera por intentos.
- Nuevo texto de ayuda bajo el campo: «Si eres el administrador, puedes dejarlo vacío.»
- Respuesta `INVITATION_REQUIRED` → mensaje de error «Escribe el código de invitación.»
- El resto de mensajes no cambia.
