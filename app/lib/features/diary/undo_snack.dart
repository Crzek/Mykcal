import 'package:flutter/material.dart';

/// Tiempo que se ofrece «Deshacer» tras un añadido rápido, una copia o quitar un favorito
/// (FR-007). El servidor admite hasta 60 s: el margen cubre la red lenta (research R4).
const quickUndoDuration = Duration(seconds: 5);

/// Aviso de [quickUndoDuration] con «Deshacer». Sustituye al aviso anterior.
void showUndoSnack(
  ScaffoldMessengerState messenger, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: quickUndoDuration,
      // Con una acción Flutter no cierra el aviso por tiempo salvo que se diga: aquí sí.
      persist: false,
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
    ),
  );
}
