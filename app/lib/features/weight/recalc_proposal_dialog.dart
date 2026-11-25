import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import '../target/recalc_dialogs.dart';

/// Respuesta del usuario a la propuesta. Cerrar sin responder devuelve `null` (US3.7).
enum RecalcChoice { accept, ignore }

Widget _line(String label, String value) => Padding(
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

/// Propuesta de recalcular el objetivo con la media semanal (FR-005–FR-008).
Future<RecalcChoice?> showRecalcProposalDialog(
  BuildContext context,
  RecalcProposal proposal,
) {
  final l10n = AppLocalizations.of(context);
  final current = proposal.current!;
  final proposed = proposal.proposed!;
  return showDialog<RecalcChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.recalcTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recalcIntro(
                formatWeight(proposal.weeklyAverageKg!),
                formatWeight(proposal.referenceWeightKg!),
              ),
            ),
            _line(l10n.targetCurrent, macroLine(l10n, current)),
            _line(l10n.targetProposed, macroLine(l10n, proposed)),
            if (proposal.wasManual) ...[
              const SizedBox(height: 12),
              Text(l10n.recalcManualWarning),
            ],
            if (proposal.largeChange) ...[
              const SizedBox(height: 12),
              Text(l10n.recalcLargeChangeWarning),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(RecalcChoice.ignore),
          child: Text(l10n.recalcIgnore),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(RecalcChoice.accept),
          child: Text(l10n.recalcAccept),
        ),
      ],
    ),
  );
}
