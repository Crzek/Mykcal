import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/format/numbers.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'copy_sources_provider.dart';
import 'diary_day_controller.dart';
import 'local_day.dart';
import 'meal_labels.dart';
import 'undo_snack.dart';

/// Máximo de entradas que se ven de cada comida antes de «+N más».
const _previewEntries = 3;

/// «Copiar de otro día» (FR-005, `contracts/ui-flows.md` §3): elige una comida de los 14 días
/// anteriores y la copia a [meal] de [date]. Tras copiar ofrece «Deshacer» durante 5 s (FR-007).
Future<void> showCopyMealSheet(
  BuildContext context, {
  required DateTime date,
  required Meal meal,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context);
  final result = await showModalBottomSheet<DiaryCopyResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CopyMealSheet(date: date, meal: meal),
  );
  if (result == null) return;
  final offset = LocalDay.utcOffsetMin(date);
  showUndoSnack(
    messenger,
    message: l10n.copyDone(result.entryIds.length, mealName(meal, l10n)),
    undoLabel: l10n.entryUndo,
    onUndo: () async {
      try {
        final day = await container
            .read(mykcalApiProvider)
            .undoCopy(result.copyId, offset);
        container.read(diaryDayControllerProvider(date).notifier).apply(day);
        messenger.showSnackBar(SnackBar(content: Text(l10n.copyUndone)));
      } on ApiFailure {
        messenger.showSnackBar(SnackBar(content: Text(l10n.quickUndoFailed)));
      }
    },
  );
}

typedef _Choice = ({DateTime date, Meal meal});

class CopyMealSheet extends ConsumerStatefulWidget {
  const CopyMealSheet({super.key, required this.date, required this.meal});

  final DateTime date;
  final Meal meal;

  @override
  ConsumerState<CopyMealSheet> createState() => _CopyMealSheetState();
}

class _CopyMealSheetState extends ConsumerState<CopyMealSheet> {
  _Choice? _selected;
  final _expanded = <_Choice>{};
  bool _saving = false;
  String? _error;

  CopyTarget get _target => (date: widget.date, meal: widget.meal);

  String _dayLabel(DateTime day, AppLocalizations l10n) {
    final today = LocalDay.today(ref.read(diaryNowProvider)());
    final weekday = DateFormat('EEEE d', 'es').format(day);
    if (LocalDay.sameDay(day, LocalDay.addDays(today, -1))) {
      return '${l10n.dayYesterday}, $weekday';
    }
    return DateFormat('EEEE d MMM', 'es').format(day);
  }

  Future<void> _copy() async {
    final choice = _selected;
    if (choice == null || _saving) return;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(mykcalApiProvider)
          .copyMeal(
            sourceDate: choice.date,
            sourceMeal: choice.meal,
            targetDate: widget.date,
            targetMeal: widget.meal,
            utcOffsetMin: LocalDay.utcOffsetMin(widget.date),
          );
      ref
          .read(diaryDayControllerProvider(widget.date).notifier)
          .apply(result.day);
      if (mounted) navigator.pop(result);
    } on NetworkFailure {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.entryOffline;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (e.code) {
          'COPY_SOURCE_EMPTY' => l10n.copySourceEmpty,
          'DIARY_DATE_OUT_OF_RANGE' => l10n.copyOutOfRange,
          _ => l10n.errServer,
        };
      });
    } on ApiFailure {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.errServer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(copySourcesProvider(_target));
    final today = LocalDay.today(ref.read(diaryNowProvider)());
    final targetDay = LocalDay.sameDay(widget.date, today)
        ? l10n.diaryToday.toLowerCase()
        : DateFormat('EEEE d MMM', 'es').format(widget.date);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.copyTitle(mealName(widget.meal, l10n), targetDay),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            Flexible(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ConnectionErrorView(
                  offline: error is NetworkFailure,
                  onRetry: () => ref.invalidate(copySourcesProvider(_target)),
                ),
                data: (days) => days.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.copyEmpty),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final day in days) ..._day(day, l10n, theme),
                        ],
                      ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(96, 52),
                    ),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(96, 52),
                    ),
                    onPressed: _selected == null || _saving ? null : _copy,
                    child: Text(_error != null ? l10n.retry : l10n.copyAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _day(CopySourceDay day, AppLocalizations l10n, ThemeData theme) {
    final label = _dayLabel(day.date, l10n);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
        child: Semantics(
          header: true,
          child: Text(label, style: theme.textTheme.titleSmall),
        ),
      ),
      for (final meal in day.meals) _option(day.date, label, meal, l10n, theme),
    ];
  }

  String _entryText(CopySourceEntry e, AppLocalizations l10n) {
    final servings = e.servings;
    final amount = servings == null
        ? l10n.diaryEntryQuantity(formatDecimal(e.quantity), e.baseUnit)
        : l10n.diaryEntryServings(
            formatDecimal(servings),
            servings == 1 ? l10n.diaryServingOne : l10n.diaryServingMany,
            formatDecimal(e.quantity),
            e.baseUnit,
          );
    return '${e.foodName} $amount';
  }

  Widget _option(
    DateTime date,
    String dayLabel,
    CopySourceMeal meal,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final choice = (date: date, meal: meal.meal);
    final selected = _selected == choice;
    final expanded = _expanded.contains(choice);
    final shown = expanded
        ? meal.entries
        : meal.entries.take(_previewEntries).toList();
    final hidden = meal.entries.length - shown.length;
    final name = mealName(meal.meal, l10n);
    final kcal = formatDecimal(meal.kcal);
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: l10n.copyOptionSemantics(
        name,
        dayLabel,
        kcal,
        meal.entries.length,
        meal.entries.map((e) => _entryText(e, l10n)).join(', '),
      ),
      excludeSemantics: true,
      onTap: _saving ? null : () => setState(() => _selected = choice),
      child: Card(
        color: selected ? theme.colorScheme.secondaryContainer : null,
        child: InkWell(
          onTap: _saving ? null : () => setState(() => _selected = choice),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(l10n.diaryEntryKcal(kcal)),
                          ],
                        ),
                        for (final e in shown)
                          Text(
                            _entryText(e, l10n),
                            style: theme.textTheme.bodySmall,
                          ),
                        if (hidden > 0)
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () =>
                                setState(() => _expanded.add(choice)),
                            child: Text(l10n.copyMore(hidden)),
                          ),
                        if (meal.valuesChanged)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l10n.copyValuesChanged,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
