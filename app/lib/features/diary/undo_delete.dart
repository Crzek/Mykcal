import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../l10n/app_localizations.dart';
import 'diary_day_controller.dart';
import 'local_day.dart';

/// Tiempo que se ofrece «Deshacer»; el servidor admite 60 s, así que hay margen (research R8).
const undoDuration = Duration(seconds: 10);

/// Aviso «{nombre} borrado» con «Deshacer», que repone la entrada con sus mismos valores.
void showUndoDelete(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  WidgetRef ref, {
  required DiaryEntry entry,
  required DateTime date,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.entryDeleted(entry.foodName)),
      duration: undoDuration,
      // Con una acción Flutter no cierra el aviso por tiempo salvo que se diga: aquí sí.
      persist: false,
      action: SnackBarAction(
        label: l10n.entryUndo,
        onPressed: () async {
          try {
            final day = await ref
                .read(mykcalApiProvider)
                .restoreEntry(entry.id, LocalDay.utcOffsetMin(date));
            ref.read(diaryDayControllerProvider(date).notifier).apply(day);
          } on ApiFailure {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.entryUndoFailed)),
            );
          }
        },
      ),
    ),
  );
}
