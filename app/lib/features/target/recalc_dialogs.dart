import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';

/// `2.759 kcal · P 144 g · C 373 g · G 77 g`
String macroLine(AppLocalizations l10n, TargetValues v) => l10n.macroSummary(
  formatInt(v.kcal),
  formatInt(v.proteinG),
  formatInt(v.carbsG),
  formatInt(v.fatG),
);

Widget _labelled(BuildContext context, String label, String value) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: value),
      ],
    ),
  ),
);

/// Objetivo recalculado automáticamente: antes → ahora (US2.4).
Future<void> showTargetUpdatedDialog(
  BuildContext context, {
  required TargetValues previous,
  required TargetValues current,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.targetUpdatedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelled(
            dialogContext,
            l10n.targetBefore,
            macroLine(l10n, previous),
          ),
          _labelled(dialogContext, l10n.targetNow, macroLine(l10n, current)),
        ],
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}

/// Objetivo editado a mano: se propone recalcular. `true` si el usuario acepta (US3.2).
Future<bool> showRecalculationProposal(
  BuildContext context, {
  required TargetValues current,
  required TargetValues proposed,
}) async {
  final l10n = AppLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.proposedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.proposedBody),
          _labelled(
            dialogContext,
            l10n.targetCurrent,
            macroLine(l10n, current),
          ),
          _labelled(
            dialogContext,
            l10n.targetProposed,
            macroLine(l10n, proposed),
          ),
        ],
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.keepMine),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.recalculate),
        ),
      ],
    ),
  );
  return accepted ?? false;
}
