import 'package:flutter/material.dart';

import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';

/// Valores nutricionales por 100 g o 100 ml del alimento de una línea (solo lo que se suma).
class Per100 {
  const Per100({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  double kcalFor(double grams) => kcal * grams / 100;
}

/// Una línea editable de la propuesta de la IA.
class ProposalLine {
  ProposalLine({
    required this.aiName,
    required this.grams,
    this.foodId,
    this.foodName,
    this.per100,
    this.flagged = false,
  });

  final String aiName;
  double grams;
  String? foodId;
  String? foodName;
  Per100? per100;
  bool flagged;

  bool get matched => foodId != null;
  bool get valid => matched && per100 != null && grams > 0 && grams <= 10000;
}

/// Fila de la propuesta (`contracts/ui-flows.md` §5): nombre de la IA, el alimento de la base, y
/// las acciones. Los valores nutricionales son siempre los del alimento de la base.
class ProposedItemTile extends StatelessWidget {
  const ProposedItemTile({
    super.key,
    required this.line,
    required this.onEditGrams,
    required this.onChange,
    required this.onCreate,
    required this.onRemove,
  });

  final ProposalLine line;
  final VoidCallback onEditGrams;
  final VoidCallback onChange;
  final VoidCallback onCreate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final grams = formatDecimal(line.grams);
    final amount = line.per100 == null
        ? l10n.proposalGrams(grams)
        : l10n.proposalGramsKcal(
            grams,
            formatDecimal(line.per100!.kcalFor(line.grams).roundToDouble()),
          );
    final warnColor = theme.colorScheme.error;
    return Card(
      color: line.matched ? null : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.proposalAiName(line.aiName),
              style: theme.textTheme.bodySmall,
            ),
            if (line.matched)
              Text(line.foodName!, style: theme.textTheme.titleMedium)
            else
              Text(
                l10n.proposalNoMatch,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            InkWell(
              onTap: onEditGrams,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    if (line.flagged)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: warnColor,
                          semanticLabel: l10n.proposalFlagged,
                        ),
                      ),
                    Text(amount, style: theme.textTheme.bodyLarge),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_outlined, size: 16),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (line.matched)
                  TextButton(
                    onPressed: onChange,
                    child: Text(l10n.proposalChange),
                  )
                else ...[
                  TextButton(
                    onPressed: onChange,
                    child: Text(l10n.proposalSearch),
                  ),
                  TextButton(
                    onPressed: onCreate,
                    child: Text(l10n.proposalCreate),
                  ),
                ],
                TextButton(
                  onPressed: onRemove,
                  child: Text(l10n.proposalRemove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
