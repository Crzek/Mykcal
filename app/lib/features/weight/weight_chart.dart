import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import 'weight_controller.dart';

/// Resumen accesible de la gráfica (F2.4): también es la etiqueta semántica del lienzo.
String weightSummaryText(AppLocalizations l10n, WeightChartSummary s) {
  final parts = <String>[
    if (s.currentWeightKg != null)
      l10n.weightSummaryCurrent(formatWeight(s.currentWeightKg!)),
    s.weeklyAverageKg != null
        ? l10n.weightSummaryAverage(formatWeight(s.weeklyAverageKg!))
        : l10n.weightSummaryNoAverage,
    s.changeKg != null
        ? l10n.weightSummaryChange(_signed(s.changeKg!))
        : l10n.weightSummaryNoChange,
  ];
  return parts.join('. ');
}

String _signed(double value) =>
    value > 0 ? '+${formatWeight(value)}' : formatWeight(value);

/// Selector de periodo, gráfica (`fl_chart`) y resumen textual (US2, F2).
class WeightChartSection extends ConsumerStatefulWidget {
  const WeightChartSection({super.key});

  @override
  ConsumerState<WeightChartSection> createState() => _WeightChartSectionState();
}

class _WeightChartSectionState extends ConsumerState<WeightChartSection> {
  String _period = 'p30';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = ref.watch(weightChartProvider(_period));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'p30', label: Text(l10n.weightPeriod30)),
            ButtonSegment(value: 'p90', label: Text(l10n.weightPeriod90)),
            ButtonSegment(value: 'all', label: Text(l10n.weightPeriodAll)),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.single),
        ),
        const SizedBox(height: 12),
        chart.when(
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              e is NetworkFailure ? l10n.errOffline : l10n.weightChartLoadError,
              textAlign: TextAlign.center,
            ),
          ),
          data: (data) => _ChartBody(chart: data),
        ),
      ],
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({required this.chart});

  final WeightChart chart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = weightSummaryText(l10n, chart.summary);
    if (chart.points.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.weightChartNeedMore, textAlign: TextAlign.center),
          ),
          Text(summary),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l10n.weightChartLabel(summary),
          image: true,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 220,
              child: _LineChart(points: chart.points),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(summary),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});

  final List<WeightChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = points.first.date;
    double x(DateTime d) => d.difference(first).inDays.toDouble();

    final weightSpots = [for (final p in points) FlSpot(x(p.date), p.weightKg)];
    // La media solo existe en los días con ≥3 registros; un hueco corta la línea (F2.3).
    final averageSpots = <FlSpot>[];
    for (final p in points) {
      if (p.averageKg != null) {
        averageSpots.add(FlSpot(x(p.date), p.averageKg!));
      } else if (averageSpots.isNotEmpty && !averageSpots.last.isNull()) {
        averageSpots.add(FlSpot.nullSpot);
      }
    }
    final values = [
      for (final p in points) ...[p.weightKg, ?p.averageKg],
    ];
    final minY = (values.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();
    final maxX = x(points.last.date);
    final dateFormat = DateFormat('d MMM', 'es');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX == 0 ? 1 : maxX,
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              maxIncluded: false,
              minIncluded: false,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatDecimal(value),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxX == 0 ? 1 : maxX,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  dateFormat.format(first.add(Duration(days: value.round()))),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: weightSpots,
            barWidth: 0,
            color: scheme.onSurfaceVariant,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: scheme.onSurfaceVariant,
                strokeWidth: 0,
              ),
            ),
          ),
          if (averageSpots.isNotEmpty)
            LineChartBarData(
              spots: averageSpots,
              isCurved: false,
              barWidth: 3,
              color: scheme.primary,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}
