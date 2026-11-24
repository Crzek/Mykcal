import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';

/// Una línea del resumen: un nutriente con lo consumido, el objetivo y lo que queda.
class SummaryLine {
  const SummaryLine({
    required this.label,
    required this.unit,
    required this.consumed,
    required this.target,
    required this.remaining,
    this.isMax = false,
    this.incomplete = false,
  });

  final String label;
  final String unit;
  final double consumed;
  final double target;

  /// `objetivo − consumido`; negativo es exceso.
  final double remaining;

  /// El objetivo es un máximo (sodio, FR-007).
  final bool isMax;

  /// Alguna entrada no tiene este dato y cuenta como 0 (FR-008).
  final bool incomplete;

  bool get over => remaining < 0;

  /// Para la barra de progreso: 0 a 1.
  double get progress => target <= 0
      ? (consumed > 0 ? 1 : 0)
      : (consumed / target).clamp(0.0, 1.0);

  String consumedText() => isMax
      ? '${formatDecimal(consumed)} $unit'
      : '${formatDecimal(consumed)} / ${formatDecimal(target)} $unit';

  String targetText(AppLocalizations l10n) =>
      l10n.summaryMax(formatDecimal(target), unit);

  String remainingText(AppLocalizations l10n) {
    final value = formatDecimal(remaining.abs());
    if (!over) return l10n.summaryRemaining(value, unit);
    return isMax
        ? l10n.summaryOverLimit(value, unit)
        : l10n.summaryOver(value, unit);
  }

  /// Una sola frase para el lector de pantalla.
  String semantics(AppLocalizations l10n) {
    final c = formatDecimal(consumed);
    final t = formatDecimal(target);
    final r = formatDecimal(remaining.abs());
    final sentence = switch ((isMax, over)) {
      (false, false) => l10n.summarySemanticsRemaining(label, c, t, unit, r),
      (false, true) => l10n.summarySemanticsOver(label, c, t, unit, r),
      (true, false) => l10n.summarySemanticsLimitRemaining(
        label,
        c,
        t,
        unit,
        r,
      ),
      (true, true) => l10n.summarySemanticsOverLimit(label, c, t, unit, r),
    };
    return incomplete ? '$sentence (${l10n.summaryIncomplete})' : sentence;
  }
}

SummaryLine _line(
  DiaryDay day,
  String key,
  String label,
  String unit, {
  bool isMax = false,
}) {
  final target = (day.target.toJson()[key] as num).toDouble();
  final consumed = (day.totals.consumed.toJson()[key] as num?)?.toDouble() ?? 0;
  return SummaryLine(
    label: label,
    unit: unit,
    consumed: consumed,
    target: target,
    remaining: day.remaining[key] ?? target - consumed,
    isMax: isMax,
    incomplete: day.totals.incomplete.contains(key),
  );
}

/// Calorías y macros del resumen (FR-006).
List<SummaryLine> mainLines(DiaryDay day, AppLocalizations l10n) => [
  _line(day, 'kcal', l10n.nutrientKcal, 'kcal'),
  _line(day, 'protein_g', l10n.nutrientProtein, 'g'),
  _line(day, 'carbs_g', l10n.nutrientCarbs, 'g'),
  _line(day, 'fat_g', l10n.nutrientFat, 'g'),
];

/// Fibra y los 7 micros del detalle (FR-007). El sodio es un máximo.
List<SummaryLine> detailLines(DiaryDay day, AppLocalizations l10n) => [
  _line(day, 'fiber_g', l10n.nutrientFiber, 'g'),
  _line(day, 'sodium_mg', l10n.nutrientSodium, 'mg', isMax: true),
  _line(day, 'potassium_mg', l10n.nutrientPotassium, 'mg'),
  _line(day, 'calcium_mg', l10n.nutrientCalcium, 'mg'),
  _line(day, 'iron_mg', l10n.nutrientIron, 'mg'),
  _line(day, 'magnesium_mg', l10n.nutrientMagnesium, 'mg'),
  _line(day, 'vitamin_d_ug', l10n.nutrientVitD, 'µg'),
  _line(day, 'vitamin_c_mg', l10n.nutrientVitC, 'mg'),
];

/// Fila visual de una [SummaryLine]: el exceso va con icono y texto, además del color (FR-014).
class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key, required this.line});

  final SummaryLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.error,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      container: true,
      label: line.semantics(l10n),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(line.label, style: theme.textTheme.titleSmall),
                ),
                const SizedBox(width: 8),
                Text(line.consumedText()),
              ],
            ),
            if (line.isMax)
              Align(
                alignment: Alignment.centerRight,
                child: Text(line.targetText(l10n)),
              ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: line.progress,
              color: line.over ? scheme.error : scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (line.over) ...[
                  Icon(Icons.warning_amber, size: 18, color: scheme.error),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    line.remainingText(l10n),
                    style: line.over ? overStyle : theme.textTheme.bodyMedium,
                  ),
                ),
                if (line.incomplete) ...[
                  const Spacer(),
                  Tooltip(
                    message: l10n.summaryIncompleteHelp,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 4),
                        Text(l10n.summaryIncomplete),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
