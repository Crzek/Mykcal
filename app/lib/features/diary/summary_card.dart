import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import 'summary_lines.dart';

/// Resumen del día: calorías y macros con consumido, objetivo y restante (FR-006).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.day,
    required this.onDetail,
    required this.onTarget,
  });

  final DiaryDay day;
  final VoidCallback onDetail;
  final VoidCallback onTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.summaryTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            for (final line in mainLines(day, l10n)) SummaryRow(line: line),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDetail,
                    child: Text(l10n.summaryDetail),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTarget,
                    child: Text(l10n.summaryTarget),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
