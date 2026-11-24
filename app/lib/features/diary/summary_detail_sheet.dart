import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import 'summary_lines.dart';

/// Hoja con fibra y los 7 micros del día (FR-007, US1.4).
Future<void> showSummaryDetail(BuildContext context, DiaryDay day) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(child: SummaryDetailSheet(day: day)),
      ),
    );

class SummaryDetailSheet extends StatelessWidget {
  const SummaryDetailSheet({super.key, required this.day});

  final DiaryDay day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lines = detailLines(day, l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.summaryDetailTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines) SummaryRow(line: line),
          if (lines.any((l) => l.incomplete)) ...[
            const SizedBox(height: 8),
            Text(l10n.summaryIncompleteHelp),
          ],
        ],
      ),
    );
  }
}
