import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'local_day.dart';

/// Cabecera del diario: ‹ día › y el calendario, con «Ir a hoy» en un día pasado (US4).
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.date,
    required this.today,
    required this.first,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final DateTime date;
  final DateTime today;

  /// Primer día que se puede ver: el del alta.
  final DateTime first;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  bool get isToday => LocalDay.sameDay(date, today);

  String title(AppLocalizations l10n) {
    if (isToday) return l10n.diaryToday;
    if (LocalDay.sameDay(date, LocalDay.addDays(today, -1))) {
      return l10n.dayYesterday;
    }
    return DateFormat('EEEE d MMM', 'es').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canGoBack = LocalDay.isAfter(date, first);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: l10n.dayPrevious,
              icon: const Icon(Icons.chevron_left),
              onPressed: canGoBack ? onPrevious : null,
            ),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title(l10n),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: l10n.dayPick,
              icon: const Icon(Icons.calendar_today),
              onPressed: onPick,
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: l10n.dayNext,
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday ? null : onNext,
            ),
          ],
        ),
        if (!isToday)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onToday, child: Text(l10n.dayGoToday)),
          ),
      ],
    );
  }
}
